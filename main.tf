provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "dev-vpc-hbcc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name  = "dev-vpc-hbcc"
    Group = "DevSecOps"
  }
}

resource "aws_instance" "dev-ec2-www" {
  ami                    = "ami-062f7200baf2fa504"
  isntance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.dev-sg-hbcc.id]

  user_data = <<-EOF
                #!/bin/bash
                echo "Go to the sky!" > index.html
                nohup busybox httpd -f -p 8080 &
                EOF
  tags = {
    Name  = "dev-ec2-www"
    Group = "DevSecOps"
  }
}

resource "aws_security_group" "dev-sg-hbcc" {
  name = "www-sg-hbcc"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
