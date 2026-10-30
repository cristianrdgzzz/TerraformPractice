# ================================================================================
# TERRAFORM CONFIGURATION AND PROVIDER SETUP
# ================================================================================
# This configuration sets up the required Terraform version and AWS provider.
# It ensures compatibility with Terraform 1.x and uses AWS provider version 4.x.

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
  #   terraform init -backend-config=../backend.hcl
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
  # Once uncommented, other Terraform configurations (database, web server cluster)
  # can reference this same backend to store their state in the same S3 bucket
  # using the same partial configuration approach.
  #
  # backend "s3" {
  #   # Path within the bucket where THIS MODULE'S state file is stored
  #   # Each module must have a UNIQUE key to avoid overwriting other states
  #   key = "global/s3/terraform.tfstate"

  #   # IMPORTANT: Variables are not allowed
  #   # AWS region where the S3 bucket and DynamoDB table are located
  #   region         = "us-east-2"

  #   # DynamoDB table name for state locking
  #   # This prevents concurrent modifications and ensures data consistency
  #   dynamodb_table = "terraform-table"

  #   # Enable encryption of state files at rest
  #   # This adds a second layer of encryption on top of S3's default encryption
  #   encrypt        = true
  # # The other settings (bucket, region, dynamodb_table, encrypt)
  # # are provided via -backend-config=../backend.hcl when running terraform init
  # }
}

# ================================================================================
# AWS PROVIDER CONFIGURATION
# ================================================================================
# Configure the AWS provider to use the region specified by the aws_region variable.
# This allows you to create the S3 bucket and DynamoDB table in any AWS region,
# making the configuration more flexible and reusable.

provider "aws" {
  # Use the aws_region variable to determine which region to deploy to
  # Default value is "us-east-2" but can be overridden via -var or terraform.tfvars
  region = var.aws_region
}

# ================================================================================
# S3 BUCKET FOR TERRAFORM STATE STORAGE
# ================================================================================
# This S3 bucket stores the Terraform state files (terraform.tfstate)
# The state file contains information about all the infrastructure managed by Terraform, 
# including resource IDs, attributes, and metadata required for future operations.

resource "aws_s3_bucket" "terraform_state" {
  # Use the bucket name provided via variables (must be globally unique among AWS customers)
  bucket = var.bucket_name

  # ================================================================================
  # LIFECYCLE PROTECTION: prevent_destroy
  # ================================================================================
  # This lifecycle rule prevents accidental destruction of this critical S3 bucket.
  # The Terraform state file is essential for infrastructure management and contains
  # all the metadata about your AWS resources. Destroying this bucket would make it
  # impossible to manage your infrastructure with Terraform going forward.
  #
  # IMPORTANT PRODUCTION SAFETY MEASURE:
  # - Any attempt to run "terraform destroy" will FAIL with an error
  # - This is intentional and protects against accidental data loss
  # - The bucket remains in AWS even after "terraform destroy"
  #
  # TO ACTUALLY DELETE THIS BUCKET:
  # 1. First, delete all the infrastructure that depends on this state
  #    (database, web servers, etc.)
  # 2. Then, comment out this lifecycle block:
  #    # lifecycle {
  #    #   prevent_destroy = true
  #    # }
  # 3. Run "terraform init -reconfigure" to update the configuration
  # 4. Run "terraform destroy" to remove the bucket
  #
  # ALTERNATIVE FOR TESTING:
  # If you need to destroy this bucket for testing purposes, you can:
  # 1. Temporarily set force_destroy = true below
  # 2. Comment out prevent_destroy
  # 3. Run terraform destroy
  # 4. Then remove the bucket manually from AWS Console if needed
  #
  # DO NOT disable this protection in production environments!
  lifecycle {
    prevent_destroy = true
  }

  # force_destroy = true
  # WARNING: Setting force_destroy = true will allow Terraform to delete this bucket
  # EVEN IF IT CONTAINS FILES. This is dangerous and should only be used in:
  # - Non-production/testing environments
  # - When you are certain all state files are backed up elsewhere
  # - When you explicitly want to delete everything
  # Never enable this in production!
}

# ------------------------- EXTRA LAYERS OF PROTECTION ---------------------------

# ================================================================================
# S3 BUCKET VERSIONING
# ================================================================================
# Enable versioning to maintain a complete history of all state file changes.
# Every update to a file in the bucket -> creates new version of that file.
# This allows you to recover previous versions of the state if needed, which is
# critical for debugging and understanding what changed in your infrastructure.

resource "aws_s3_bucket_versioning" "enabled" {
  # Reference the S3 bucket created above
  bucket = aws_s3_bucket.terraform_state.id

  # Enable versioning on the bucket
  versioning_configuration {
    status = "Enabled"
  }
}

# ================================================================================
# S3 BUCKET ENCRYPTION CONFIGURATION (SSE - PROTECT SECRETS!)
# ================================================================================
# Enable server-side encryption to protect state files at rest. This ensures
# that sensitive data stored in the Terraform state (database passwords,
# private keys, etc.) is encrypted using AWS S3's encryption mechanisms.

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  # Reference the S3 bucket created above
  bucket = aws_s3_bucket.terraform_state.id

  # Define the encryption rule
  rule {
    apply_server_side_encryption_by_default {
      # Use AWS S3-managed keys (AES256) for encryption
      # This is sufficient for most use cases and is cost-effective
      sse_algorithm = "AES256"
    }
  }
}

# ================================================================================
# S3 BUCKET PUBLIC ACCESS BLOCK
# ================================================================================
# Block all public access to the S3 bucket. This is a critical security measure
# because the Terraform state file contains sensitive information (credentials,
# resource IDs, private data) that should NEVER be accessible to the public.
# Prevents that no one can ever accidentally make this S3 bucket public.

# NOTE: S3 buckets are PRIVATE BY DEFAULT, but as they are often used to serve
# static public content, sometimes becomes buckets public (error!).

resource "aws_s3_bucket_public_access_block" "public_access" {
  # Reference the S3 bucket created above
  bucket = aws_s3_bucket.terraform_state.id

  # Block public ACLs: Prevents anyone from using ACLs to grant public access
  block_public_acls = true

  # Block public bucket policies: Prevents bucket policies from granting public access
  block_public_policy = true

  # Ignore public ACLs: Treats any existing public ACLs as if they don't exist
  ignore_public_acls = true

  # Restrict public buckets: Prevents public access even if configured elsewhere
  restrict_public_buckets = true
}

# ================================================================================
# DYNAMODB TABLE FOR TERRAFORM STATE LOCKING
# ================================================================================

# DynamoDB is  Amazon’s distributed key-value store. It supports strongly consistent
# reads and conditional writes, which are all the ingredients you need for a distributed lock system.

# This DynamoDB table implements state locking, which prevents concurrent
# Terraform operations from corrupting the state. When Terraform runs, it
# creates a lock entry in this table. If another Terraform process tries to
# run simultaneously, it will wait or fail, ensuring data consistency.

resource "aws_dynamodb_table" "terraform_locks" {
  # Use the table name provided via variables
  name = var.table_name

  # Use pay-per-request billing mode for cost efficiency (suitable for low traffic)
  billing_mode = "PAY_PER_REQUEST"

  # Define the primary key (hash key) for the lock table
  hash_key = "LockID"

  # Define the LockID attribute
  # This attribute will store unique identifiers for each Terraform state lock
  attribute {
    name = "LockID"
    # "S" = String type
    type = "S"
  }
}
