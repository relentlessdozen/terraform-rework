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
