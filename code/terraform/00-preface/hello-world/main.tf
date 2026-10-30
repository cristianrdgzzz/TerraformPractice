terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east" # Default AWS Europe account: eu-north-1
}

# IMPORTANT: this ami is not available on eu-north-1

resource "aws_instance" "example" {
  ami           = "ami-0fb653ca2d3203ac1"
  instance_type = "t3.micro" # Change from t2.micro to t3.micro (free plan)
}

