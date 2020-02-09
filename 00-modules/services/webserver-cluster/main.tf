provider "aws" {
  region = "us-east-1"

  # Version identifier
  version = "~> 2.0"
}

## Locals definition ##

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}

## Backend ##

terraform {
  backend "s3" {
    # Bucket name from above goes here
    bucket = "tf-state-rework-pp"
    # This won't be the key across all environments | key = "stage/services/webserver-cluster/terraform.tfstate"
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

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-1"
  }
}

data "aws_vpc" "dev-vpc-hbcc" {
  default = true
}

data "aws_subnet_ids" "dev-vpc-hbcc" {
  vpc_id = data.aws_vpc.dev-vpc-hbcc.id
}

data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  }
}

resource "aws_launch_configuration" "ec2-www" {
  image_id        = "ami-07ebfd5b3428b6f4d"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.www-ec2.id]
  user_data       = data.template_file.user_data.rendered

  # Required since we are pointing to an old resource after replacing it
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ec2-asg" {
  name                 = "${var.cluster_name}-asg"
  launch_configuration = aws_launch_configuration.ec2-www.name
  vpc_zone_identifier  = data.aws_subnet_ids.dev-vpc-hbcc.ids

  target_group_arns = [aws_lb_target_group.dev-ec2-tg.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}

# Configure the LB

resource "aws_lb" "lb" {
  name               = "${var.cluster_name}ec2-asg"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.dev-vpc-hbcc.ids
  security_groups    = [aws_security_group.dev-alb.id]
}

# Configure the LB Listener

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.dev-lb.arn
  port              = locals.http_port
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

resource "aws_lb_listener_rule" "lb-lr" {
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

# Split Security group and rules into separate resources #

resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
 
  # Allow ingress HTTP 
    from_port   = locals.http_port
    to_port     = locals.http_port
    protocol    = locals.tcp_protocol
    cidr_blocks = locals.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  # Allow all outbound requests
    from_port   = locals.any_port
    to_port     = locals.any_port
    protocol    = locals.any_protocol
    cidr_blocks = locals.all_ips
}


# Create target group

resource "aws_lb_target_group" "tg" {
  name     = "${var.cluster_name}-tg"
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

resource "aws_security_group" "www-ec2" {
  name = "$(var.cluster_name}-www-ec2"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = locals.tcp_protocol
    cidr_blocks = locals.all_ips
  }
}
