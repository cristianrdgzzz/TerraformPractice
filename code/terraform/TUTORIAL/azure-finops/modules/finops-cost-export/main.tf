# ============================================================================
# Azure FinOps Cost Export Module - Main Configuration
# ============================================================================
# This module configures automated export of Azure billing data to a Storage Account.
# It supports both creating a new Storage Account or using an existing one.
#
# Key Features:
# - Automated daily cost exports
# - Configurable export format (CSV/Parquet)
# - Support for existing Storage Accounts via data sources or module references
# - Flexible time periods and query types
# ============================================================================

# ----------------------------------------------------------------------------
# Storage Account Configuration
# ----------------------------------------------------------------------------
# OPTION 1: Create a new Storage Account (default behavior)
# This is useful for standalone deployments or when you need a dedicated
# storage account for cost exports.
# ----------------------------------------------------------------------------
resource "azurerm_storage_account" "export" {
  count = var.create_storage_account ? 1 : 0

  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = var.storage_account_tier
  account_replication_type        = var.storage_account_replication_type
  account_kind                    = var.storage_account_kind
  min_tls_version                 = var.storage_min_tls_version
  allow_nested_items_to_be_public = false

  # Enable blob versioning and soft delete for data protection
  blob_properties {
    versioning_enabled = var.enable_blob_versioning
    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }
  }

  # Network rules (optional - defaults to allow all)
  dynamic "network_rules" {
    for_each = var.storage_network_rules != null ? [var.storage_network_rules] : []
    content {
      default_action             = network_rules.value.default_action
      ip_rules                   = network_rules.value.ip_rules
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
      bypass                     = network_rules.value.bypass
    }
  }

  tags = merge(
    var.tags,
    {
      Purpose     = "FinOps-CostExport"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# OPTION 2: Reference an existing Storage Account via data source
# ----------------------------------------------------------------------------
# If you have a centralized storage account managed by a shared-services module,
# use this data source instead of creating a new one:
#
# data "azurerm_storage_account" "existing" {
#   count = var.create_storage_account ? 0 : 1
#   name                = var.existing_storage_account_name
#   resource_group_name = var.existing_storage_account_resource_group_name
# }
#
# Then reference it in the container and export resources:
# storage_account_id = var.create_storage_account ? azurerm_storage_account.export[0].id : data.azurerm_storage_account.existing[0].id
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# OPTION 3: Reference a Storage Account created by a module
# ----------------------------------------------------------------------------
# If you're using a centralized storage_account module (e.g., from a shared
# infrastructure repository), you can pass the storage account ID directly:
#
# module "shared_storage" {
#   source = "git::https://github.com/org/terraform-azurerm-storage-account.git"
#   # ... storage account configuration
# }
#
# module "cost_export" {
#   source = "./modules/finops-cost-export"
#   # ... other variables
#   create_storage_account = false
#   existing_storage_account_id = module.shared_storage.storage_account_id
# }
#
# This approach is recommended for enterprise environments where storage
# accounts are managed centrally for compliance, security, and cost optimization.
# ----------------------------------------------------------------------------

# Local value to determine which storage account ID to use
locals {
  storage_account_id   = var.create_storage_account ? azurerm_storage_account.export[0].id : var.existing_storage_account_id
  storage_account_name = var.create_storage_account ? azurerm_storage_account.export[0].name : var.existing_storage_account_name
}

# ----------------------------------------------------------------------------
# Storage Container for Cost Exports
# ----------------------------------------------------------------------------
resource "azurerm_storage_container" "export" {
  name                  = var.container_name
  storage_account_name  = local.storage_account_name
  container_access_type = var.container_access_type
  # Note: storage_account_name is deprecated but still required for azurerm_storage_container

  # Metadata for tracking
  metadata = {
    Purpose      = "CostExport"
    ManagedBy    = "Terraform"
    ExportType   = var.export_name
    LastModified = timestamp()
  }
}

# ----------------------------------------------------------------------------
# Cost Management Export Configuration
# ----------------------------------------------------------------------------
resource "azurerm_cost_management_export_resource_group" "export" {
  name                         = var.export_name
  resource_group_id            = var.resource_group_id
  recurrence_type              = var.recurrence_type
  recurrence_period_start_date = var.recurrence_period_start_date != null ? var.recurrence_period_start_date : formatdate("YYYY-MM-DD'T'00:00:00Z", timestamp())
  recurrence_period_end_date   = var.recurrence_period_end_date != null ? var.recurrence_period_end_date : formatdate("YYYY-MM-DD'T'00:00:00Z", timeadd(timestamp(), "${var.recurrence_period_years * 8760}h"))

  delivery_info {
    storage_account_id = local.storage_account_id
    container_name     = azurerm_storage_container.export.name
    root_folder_path   = var.root_folder_path
  }

  query {
    type       = var.query_type
    time_frame = var.query_time_frame
  }

  # Enable export only if explicitly enabled
  enabled = var.export_enabled
}
