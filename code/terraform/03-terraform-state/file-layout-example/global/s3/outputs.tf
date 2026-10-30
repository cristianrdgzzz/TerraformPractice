# ================================================================================
# OUTPUT VARIABLES FOR BACKEND REFERENCE
# ================================================================================
# These outputs display the S3 bucket and DynamoDB table information that is needed
# to configure the S3 backend in other Terraform configurations (database and web
# server cluster).
#
# IMPORTANT: This project uses PARTIAL BACKEND CONFIGURATION to reduce duplication.
# Instead of copying these values to every module, you:
#
# 1. Update backend.hcl (in the root directory) with the values below
# 2. Each module uses: terraform init -backend-config=../backend.hcl
# 3. Each module only needs to define a unique 'key' in its backend "s3" block
#
# This approach eliminates copy-paste duplication and makes it easy to change
# backend settings in one place. See BACKEND_SETUP.md for complete instructions.

output "s3_bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "The ARN of the S3 bucket for storing Terraform state files. Example: arn:aws:s3:::terraform-up-and-running-state"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "The name of the S3 bucket for storing Terraform state files. Use this in the 'bucket' parameter of backend configuration in other modules."
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "The name of the DynamoDB table for state locking. Use this in the 'dynamodb_table' parameter of backend configuration in other modules."
}

output "dynamodb_table_arn" {
  value       = aws_dynamodb_table.terraform_locks.arn
  description = "The ARN of the DynamoDB table for state locking. Example: arn:aws:dynamodb:us-east-2:123456789:table/terraform-up-and-running-locks"
}

output "backend_config_example" {
  value       = <<-EOT
    # ====================================================================================
    # PARTIAL BACKEND CONFIGURATION FOR OTHER MODULES (DRY APPROACH)
    # ====================================================================================
    # This project uses PARTIAL BACKEND CONFIGURATION to avoid duplication.
    #
    # STEP 1: Update backend.hcl in the root directory with these values:
    # ===================================================================
    # bucket         = "${aws_s3_bucket.terraform_state.id}"
    # region         = "us-east-2"
    # dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
    # encrypt        = true
    #
    # STEP 2: Add ONLY the 'key' parameter to each module's terraform block:
    # =======================================================================
    # For stage/data-stores/mysql/main.tf:
    # terraform {
    #   backend "s3" {
    #     key = "stage/data-stores/mysql/terraform.tfstate"
    #   }
    # }
    #
    # For stage/services/webserver-cluster/main.tf:
    # terraform {
    #   backend "s3" {
    #     key = "stage/services/webserver-cluster/terraform.tfstate"
    #   }
    # }
    #
    # STEP 3: Initialize each module with the shared backend configuration:
    # =====================================================================
    # cd stage/data-stores/mysql
    # terraform init -backend-config=../../backend.hcl
    #
    # cd stage/services/webserver-cluster
    # terraform init -backend-config=../../backend.hcl
    #
    # This approach:
    # ✓ Eliminates copy-paste duplication
    # ✓ Makes it easy to change backend settings globally
    # ✓ Maintains unique state files for each module
    # ✓ Follows the DRY (Don't Repeat Yourself) principle
    #
    # See BACKEND_SETUP.md for complete instructions.
  EOT
  description = "Example of partial backend configuration approach (DRY - Don't Repeat Yourself)"
}
