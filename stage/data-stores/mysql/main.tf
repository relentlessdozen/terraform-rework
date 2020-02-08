provider "aws" {
  region = "us-east-1"
}

resource "aws_db_instance" "stage-pp" {
  identifier_prefix = "stage-pp"
  engine            = "mysql"
  allocated_storage = 10
  instance_class    = "db.t2.micro"
  name              = "example_database"
  username          = "admin"

  # How should we set the password?
  password = var.db_password

  skip_final_snapshot = true
}


terraform {
  backend "s3" {
    # Bucket name from above goes here
    bucket = "tf-state-rework-pp"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "us-east-1"

    # Dynamo DB table from above goes here
    dynamodb_table = "pp-tf-state-locks"
    encrypt        = true
  }
}
