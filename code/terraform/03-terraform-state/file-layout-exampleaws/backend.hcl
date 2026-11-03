# ================================================================================
# SHARED S3 BACKEND CONFIGURATION
# ================================================================================
# This file contains the common backend configuration shared across all Terraform
# modules in this project. Instead of repeating bucket name, region, and DynamoDB
# table name in every module, this file defines them once.
#
# USAGE:
# Pass this file to terraform init with the -backend-config flag:
#   terraform init -backend-config=../../backend.hcl
#
# This reduces copy-paste duplication and makes it easy to change the backend
# settings in one place (e.g., if you need to migrate to a different bucket).

# The S3 bucket name where Terraform state files will be stored
# Must be globally unique across all AWS accounts
bucket = "terraform-smyha"

# AWS region where the S3 bucket and DynamoDB table are located
# Must match the region where these resources were created
region = "us-east-2"

# DynamoDB table name for state locking
# Prevents concurrent Terraform operations from corrupting the state
dynamodb_table = "terraform-table"

# Enable encryption of state files at rest
# This adds a second layer of encryption on top of S3's default encryption
encrypt = true

# ================================================================================
# NOTE: The 'key' parameter is NOT defined here because each module needs a
# unique key value to avoid overwriting the state of other modules.
#
# Each module defines its own 'key' in its terraform block:
# - global/s3/terraform.tfstate
# - stage/data-stores/mysql/terraform.tfstate
# - stage/services/webserver-cluster/terraform.tfstate
# ================================================================================
