provider "aws" {
  region = "east-us-2"
}

resource "vpc" "dev-vpc-hbcc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name  = "dev-vpc-hbcc"
    Group = "DevSecOps"
  }
}
