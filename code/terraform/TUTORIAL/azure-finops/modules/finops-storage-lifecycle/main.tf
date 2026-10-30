# ============================================================================
# Azure FinOps Storage Lifecycle Module - Main Configuration
# ============================================================================
# This module configures Azure Storage Management Policies to automatically
# move data to cooler storage tiers and delete old data, optimizing storage costs.
#
# Key Features:
# - Automatic tiering (Hot → Cool → Archive)
# - Configurable retention policies
# - Multiple rules for different containers/prefixes
# - Support for existing Storage Accounts from modules
# ============================================================================

# ----------------------------------------------------------------------------
# Storage Account Reference
# ----------------------------------------------------------------------------
# OPTION 1: Direct Storage Account ID (default)
# Pass the storage account ID directly as a variable.
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# OPTION 2: Reference Storage Account from Data Source
# ----------------------------------------------------------------------------
# If you have an existing storage account, use a data source:
#
# data "azurerm_storage_account" "existing" {
#   name                = var.storage_account_name
#   resource_group_name = var.storage_account_resource_group_name
# }
#
# Then pass the ID:
# storage_account_id = data.azurerm_storage_account.existing.id
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# OPTION 3: Reference Storage Account from Module
# ----------------------------------------------------------------------------
# If you're using a centralized storage_account module (e.g., from a shared
# infrastructure repository), you can pass the storage account ID directly:
#
# module "shared_storage" {
#   source = "git::https://github.com/org/terraform-azurerm-storage-account.git"
#   # ... storage account configuration
# }
#
# module "storage_lifecycle" {
#   source = "./modules/finops-storage-lifecycle"
#   storage_account_id = module.shared_storage.storage_account_id
#   # ... lifecycle rules
# }
#
# This approach is recommended for enterprise environments where storage
# accounts are managed centrally for compliance, security, and cost optimization.
# ----------------------------------------------------------------------------

# Local value for storage account ID
locals {
  storage_account_id = var.storage_account_id
}

# ----------------------------------------------------------------------------
# Storage Management Policy
# ----------------------------------------------------------------------------
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = local.storage_account_id

  # Dynamic rules based on configuration
  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      name    = rule.value.name
      enabled = rule.value.enabled

      filters {
        prefix_match = rule.value.prefix_match != null ? rule.value.prefix_match : []
        blob_types   = rule.value.blob_types != null ? rule.value.blob_types : ["blockBlob"]
      }

      actions {
        # Base blob actions (tiering and deletion)
        dynamic "base_blob" {
          for_each = rule.value.base_blob != null ? [rule.value.base_blob] : []
          content {
            tier_to_cool_after_days_since_modification_greater_than        = base_blob.value.tier_to_cool_after_days
            tier_to_archive_after_days_since_modification_greater_than     = base_blob.value.tier_to_archive_after_days
            delete_after_days_since_modification_greater_than              = base_blob.value.delete_after_days
            tier_to_cool_after_days_since_last_access_time_greater_than    = base_blob.value.tier_to_cool_after_days_since_last_access
            tier_to_archive_after_days_since_last_access_time_greater_than = base_blob.value.tier_to_archive_after_days_since_last_access
            delete_after_days_since_last_access_time_greater_than          = base_blob.value.delete_after_days_since_last_access
          }
        }

        # Snapshot actions
        dynamic "snapshot" {
          for_each = rule.value.snapshot != null ? [rule.value.snapshot] : []
          content {
            delete_after_days_since_creation_greater_than          = snapshot.value.delete_after_days_since_creation
            tier_to_cool_after_days_since_creation_greater_than    = snapshot.value.tier_to_cool_after_days_since_creation
            tier_to_archive_after_days_since_creation_greater_than = snapshot.value.tier_to_archive_after_days_since_creation
          }
        }

        # Version actions
        dynamic "version" {
          for_each = rule.value.version != null ? [rule.value.version] : []
          content {
            delete_after_days_since_creation_greater_than          = version.value.delete_after_days_since_creation
            tier_to_cool_after_days_since_creation_greater_than    = version.value.tier_to_cool_after_days_since_creation
            tier_to_archive_after_days_since_creation_greater_than = version.value.tier_to_archive_after_days_since_creation
          }
        }
      }
    }
  }
}
