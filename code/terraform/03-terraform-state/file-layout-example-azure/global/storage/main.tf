terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
  sensitive   = true
}

provider "azurerm" {
  features {}
}


# Define an Azure Resource Group for terraform state storage
# Resource groups are containers that hold related resources for an Azure solution
resource "azurerm_resource_group" "terraform_state" {
  name     = var.resource_group_name
  location = var.location
}

# Define an Azure Storage Account for Terraform state
# Storage accounts provide durable, highly available cloud storage
# This is the Azure equivalent of AWS S3 for storing Terraform state files
resource "azurerm_storage_account" "terraform_state" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # This is only here so we can destroy the storage account as part of automated tests
  # You should not enable this for production usage
  min_tls_version = "TLS1_2"
}

# Define a blob container within the storage account
# Containers are used to organize blobs (files) in the storage account
resource "azurerm_storage_container" "terraform_state" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private"
}

# Enable versioning on the blob container
# Versioning allows you to see the full revision history of your state files
resource "azurerm_storage_management_policy" "terraform_state" {
  storage_account_id = azurerm_storage_account.terraform_state.id

  rule {
    name    = "delete-old-versions"
    enabled = true
    filters {
      blob_types   = ["blockBlob"]
      prefix_match = [var.container_name]
    }
    actions {
      version_action {
        delete_after_days_since_creation = 90
      }
    }
  }
}

# Define an Azure Cosmos DB account for state locking
# Cosmos DB provides a globally distributed database for high availability
# This is the Azure equivalent of DynamoDB for state locking
resource "azurerm_cosmosdb_account" "terraform_locks" {
  name                = var.cosmos_db_account_name
  location            = azurerm_resource_group.terraform_state.location
  resource_group_name = azurerm_resource_group.terraform_state.name
  offer_type          = "Standard"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.terraform_state.location
    failover_priority = 0
  }
}

# Define a Cosmos DB SQL database for terraform locks
resource "azurerm_cosmosdb_sql_database" "terraform_locks" {
  account_name        = azurerm_cosmosdb_account.terraform_locks.name
  resource_group_name = azurerm_resource_group.terraform_state.name
  name                = var.cosmos_db_database_name
}

# Define a Cosmos DB SQL container for terraform locks
resource "azurerm_cosmosdb_sql_container" "terraform_locks" {
  account_name          = azurerm_cosmosdb_account.terraform_locks.name
  database_name         = azurerm_cosmosdb_sql_database.terraform_locks.name
  resource_group_name   = azurerm_resource_group.terraform_state.name
  name                  = var.cosmos_db_container_name
  partition_key_path    = "/LockID"
  partition_key_version = 2
}
