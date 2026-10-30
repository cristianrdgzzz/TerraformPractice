terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # This backend configuration is filled in automatically at test time by Terratest. If you wish to run this example
    # manually, uncomment and fill in the config below.

    # bucket         = "<YOUR S3 BUCKET>"
    # key            = "<SOME PATH>/terraform.tfstate"
    # region         = "us-east-2"
    # dynamodb_table = "<YOUR DYNAMODB TABLE>"
    # encrypt        = true
  }
}

# ============================================================================
# PRODUCTION ENVIRONMENT: MySQL Database with Multi-Region Replication
# ============================================================================
# This configuration uses the mysql module (modules/data-stores/mysql) to deploy
# a highly available MySQL setup with:
#   - Primary database in us-east-2 (aws.primary provider)
#   - Read replica in us-west-1 (aws.replica provider) for disaster recovery
#
# COMPARISON WITH STAGING:
#   - Staging (live/stage/data-stores/mysql): Single instance, no replication
#     for cost optimization in pre-production environments
#   - Production (this file): Multi-region replication for high availability
#     and disaster recovery
#
# KEY FEATURES:
#   1. Provider aliases: Two AWS providers for different regions
#   2. Backup retention: Enabled (backup_retention_period = 1) to support replication
#   3. Replication: Replica automatically syncs from primary
#   4. High availability: If primary region fails, replica can be promoted
# ============================================================================

provider "aws" {
  region = "us-east-2"
  alias  = "primary"
}

provider "aws" {
  region = "us-west-1"
  alias  = "replica"
}

# ============================================================================
# MODULE: MySQL Primary Database
# ============================================================================
# Creates the primary MySQL RDS instance in us-east-2.
# This instance will have backups enabled (required for replication) and will
# serve as the source for the read replica in us-west-1.
# ============================================================================
module "mysql_primary" {
  source = "../../../../modules/data-stores/mysql"

  providers = {
    aws = aws.primary
  }

  db_name = var.db_name

  db_username = var.db_username
  db_password = var.db_password

  # Must be enabled to support replication
  # Without this, AWS RDS cannot create read replicas
  backup_retention_period = 1
}

# ============================================================================
# MODULE: MySQL Read Replica
# ============================================================================
# Creates a read replica of the primary database in us-west-1.
# The replica automatically syncs data from the primary and can be promoted
# to a standalone database if the primary region fails.
#
# Note: The module's conditional logic detects replicate_source_db is set,
# so it will NOT set engine, db_name, username, or password (those come from
# the primary). See modules/data-stores/mysql/main.tf for details.
# ============================================================================
module "mysql_replica" {
  source = "../../../../modules/data-stores/mysql"

  providers = {
    aws = aws.replica
  }

  # Make this a replica of the primary
  # This tells the module to create a read replica instead of a primary database
  replicate_source_db = module.mysql_primary.arn
}
