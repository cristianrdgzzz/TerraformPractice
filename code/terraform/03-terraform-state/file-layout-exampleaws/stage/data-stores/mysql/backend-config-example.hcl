# ================================================================================
# EXAMPLE: PARTIAL BACKEND CONFIGURATION FOR MYSQL MODULE
# ================================================================================
# This is an EXAMPLE showing how to configure the S3 backend for the MySQL
# database module using partial configuration.
#
# TO USE THIS:
# 1. Add this backend block to your main.tf (uncomment it):
#
#    backend "s3" {
#      key = "stage/data-stores/mysql/terraform.tfstate"
#    }
#
# 2. Initialize with the shared backend configuration:
#    terraform init -backend-config=../../backend.hcl
#
# This way, the bucket, region, dynamodb_table, and encrypt settings
# come from ../../backend.hcl (the shared configuration), and only the
# unique 'key' is defined here in this module.
#
# BENEFITS:
# - No duplication of bucket name, region, etc.
# - Easy to change backend settings globally
# - Each module has its own unique state file
# - Follows DRY principle
# ================================================================================
