# ================================================================================
# TERRAFORM CONFIGURATION AND REMOTE STATE BACKEND
# ================================================================================
# This configuration deploys a MySQL database using RDS. The state is stored
# remotely in S3 with state locking via DynamoDB to ensure safe concurrent access.

terraform {
  # Specify the minimum and maximum Terraform versions allowed
  required_version = ">= 1.0.0, < 2.0.0"

  # Define required providers and their versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  # ================================================================================
  # S3 BACKEND CONFIGURATION (PARTIAL - DRY APPROACH)
  # ================================================================================
  # UNCOMMENT WHEN READY FOR REMOTE STATE
  # This uses PARTIAL BACKEND CONFIGURATION to reduce copy-paste duplication.
  # The shared settings (bucket, region, dynamodb_table, encrypt) are defined
  # in the backend.hcl file at the project root.
  #
  # INITIALIZATION:
  # To initialize this module with the partial configuration, run:
  #   terraform init -backend-config=../../backend.hcl
  #
  # This approach:
  # ✓ Reduces duplication across modules
  # ✓ Makes it easy to change bucket/region in one place
  # ✓ Still allows unique 'key' for each module
  # ✓ Follows the DRY (Don't Repeat Yourself) principle
  #
  # IMPORTANT: Only the 'key' is defined here. The other settings
  # (bucket, region, dynamodb_table, encrypt) come from backend.hcl
  #
  # The state file path mirrors the folder structure:
  # - This file: stage/data-stores/mysql/main.tf
  # - State file: stage/data-stores/mysql/terraform.tfstate
  # This creates a 1:1 mapping between code layout and state file location.
  #
  # backend "s3" {
  #   key = "stage/data-stores/mysql/terraform.tfstate"
  # 
  #  ! Replace this with your bucket name!
  #   bucket = "terraform-up-and-running-st
  #   key = "stage/data-stores/mysql/ter
  #   region = "us-east-2"
  #  ! Replace this with your DynamoDB table name
  #   dynamodb_table = "terraform-up-and-running-lo
  #   encrypt = true
  # }
  # IMPORTANT: The other settings (bucket, region, dynamodb_table, encrypt)
  # are provided via -backend-config=../../backend.hcl when running terraform init
}

# Configure the AWS provider to use the us-east-2 region
provider "aws" {
  region = "us-east-2"
}

# ================================================================================
# RDS MYSQL DATABASE INSTANCE
# ================================================================================
# This creates a managed MySQL database in AWS RDS. RDS handles backups,
# patches, and maintenance automatically. The database outputs (address and
# port) are stored in the state file and can be read by other Terraform
# configurations using terraform_remote_state data sources.

resource "aws_db_instance" "example" {
  # Prefix for the database instance identifier
  # The actual identifier will be: terraform-up-and-running-XXXX (XXXX = random suffix)
  identifier_prefix = "terraform-up-and-running"

  # Database engine to use
  engine = "mysql"

  # Storage allocation in GB
  allocated_storage = 10

  # Instance class determines the compute and memory resources
  # db.t3.micro is eligible for AWS free tier (if account is new)
  instance_class = "db.t3.micro"

  # Skip the final DB snapshot when destroying
  # WARNING: Setting this to true means data loss on destroy!
  # For production, use false and keep snapshots for recovery
  skip_final_snapshot = true

  # Database name (initial database to create)
  db_name = var.db_name

  # Master username for the database administrator
  username = var.db_username

  # Master user password (should come from environment variables for security)
  password = var.db_password
}
