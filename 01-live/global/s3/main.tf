provider "aws" {
  region = "us-east-1"
}

# Pack Pride (pp) State rework bucket creation
resource "aws_s3_bucket" "terraform_state" {
  bucket = "tf-state-rework-pp"

  # Prevent accidental deletion of the S3 bucket | Comment setting out if you really want to remove the bucket
  lifecycle {
    prevent_destroy = true
  }

  # Enable versioning so we can see the full history
  versioning {
    enabled = true
  }

  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Dynamo DB table used for locking
resource "aws_dynamodb_table" "pp-tf-state-locks" {
  name         = "pp-tf-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# Backend configuration that is required use resources created above
terraform {
  backend "s3" {
    # Bucket name from above goes here
    bucket = "tf-state-rework-pp"
    key    = "global/s3/terraform.tfstate"
    region = "us-east-1"

    # Dynamo DB table from above goes here
    dynamodb_table = "pp-tf-state-locks"
    encrypt        = true
  }
}
