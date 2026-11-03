# ================================================================================
# INPUT VARIABLES FOR S3 BACKEND CONFIGURATION
# ================================================================================
# These variables allow you to customize the S3 bucket and DynamoDB table names,
# as well as the AWS region where these resources will be created.

variable "bucket_name" {
  description = "The name of the S3 bucket for storing Terraform state files. Must be globally unique across all AWS accounts."
  type        = string
  # Example: "terraform-up-and-running-state-12345" | "terraform-smyha"
  # Note: S3 bucket names must be lowercase and can only contain letters, numbers, and hyphens
}

variable "table_name" {
  description = "The name of the DynamoDB table for state locking. Must be unique within this AWS account."
  type        = string
  # Example: "terraform-up-and-running-locks" | "terraform-table"
  # Note: Table names can contain alphanumeric characters, dots (.), and underscores (_)
}

variable "aws_region" {
  description = "The AWS region where the S3 bucket and DynamoDB table will be created."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-1, eu-west-1, ap-southeast-2)."
  }
}

# ================================================================================
# IMPORTANT NOTES ABOUT THESE VARIABLES
# ================================================================================
#
# bucket_name:
#   - Must be globally unique (will fail if bucket name already exists in any AWS account)
#   - Can only contain lowercase letters, numbers, and hyphens
#   - Cannot start or end with a hyphen
#   - Must be between 3 and 63 characters long
#   - Cannot contain dots (.) as this breaks SSL certificate validation
#
# table_name:
#   - Must be unique within your AWS account but can be reused in other accounts
#   - Can contain alphanumeric characters, dots (.), underscores (_), and hyphens (-)
#   - Must be between 3 and 255 characters long
#
# aws_region:
#   - Must match the region where you plan to create the S3 bucket
#   - Must match the region where you plan to create the DynamoDB table
#   - All Terraform configurations using this backend must reference the same region
#   - Default is "us-east-2" but you can override with terraform.tfvars or -var flag
#
# EXAMPLES:
#   terraform apply -var="bucket_name=my-terraform-state" -var="table_name=terraform-locks" -var="aws_region=eu-west-1"
#   terraform apply -var-file="production.tfvars"