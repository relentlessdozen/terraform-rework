provider "aws" {
  region = "us-east-1"

  # Version identifier
  verion = "~> 2.0"
}

## Backend ##

terraform {
  backend "s3" {
    # Bucket name from above goes here
    bucket = "tf-state-rework-pp"
    key    = "stage/services/webserver-cluster/terraform.tfstate"
    region = "us-east-1"

    # Dynamo DB table from above goes here
    dynamodb_table = "pp-tf-state-locks"
    encrypt        = true
  }
}

resource "aws_vpc" "dev-vpc-hbcc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name  = "dev-vpc-hbcc"
    Group = "DevSecOps"
  }
}

data "aws_vpc" "dev-vpc-hbcc" {
  default = true
}

data "aws_subnet_ids" "dev-vpc-hbcc" {
  vpc_id = data.aws_vpc.dev-vpc-hbcc.id
}

data "template_file" "user_data" {
  template = file("user-data.sh")

  vars = {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  }
}

resource "aws_launch_configuration" "dev-ec2-www" {
  image_id        = "ami-07ebfd5b3428b6f4d"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.dev-sg-hbcc.id]
  user_data       = data.template_file.user_data.rendered

  # Required since we are pointing to an old resource after replacing it
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "dev-ec2-asg" {
  launch_configuration = aws_launch_configuration.dev-ec2-www.name
  vpc_zone_identifier  = data.aws_subnet_ids.dev-vpc-hbcc.ids

  target_group_arns = [aws_lb_target_group.dev-ec2-tg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 6

}

# Configure the LB

resource "aws_lb" "dev-lb" {
  name               = "dev-ec2-asg"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.dev-vpc-hbcc.ids
  security_groups    = [aws_security_group.dev-alb.id]
}

# Configure the LB Listener

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.dev-lb.arn
  port              = 80
  protocol          = "HTTP"

  # Return 404 by default
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# Configure LB Listener rule

resource "aws_lb_listener_rule" "dev-lb-lr" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev-ec2-tg.arn
  }
}

resource "aws_security_group" "dev-alb" {
  name = "dev-alb"

  # Allow ingress HTTP 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create target group

resource "aws_lb_target_group" "dev-ec2-tg" {
  name     = "dev-ec2-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.dev-vpc-hbcc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_security_group" "dev-sg-hbcc" {
  name = "www-sg-hbcc"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
