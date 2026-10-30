# ============================================================================
# Azure FinOps Orphan Cleanup Module - Main Configuration
# ============================================================================
# This module creates Azure Resource Graph queries to identify orphaned
# resources (unattached disks, unused public IPs, etc.) for cost optimization.
#
# Key Features:
# - Identify unattached managed disks
# - Find unused public IP addresses
# - Detect other orphaned resources
# - Export queries for automation/cleanup scripts
# ============================================================================

resource "azurerm_resource_graph_query" "orphaned_disks" {
  count = var.create_orphaned_disks_query ? 1 : 0

  name              = var.orphaned_disks_query_name
  resource_group_id = var.resource_group_id
  type              = var.query_type
  description       = var.orphaned_disks_query_description

  query = var.orphaned_disks_query != null ? var.orphaned_disks_query : <<QUERY
Resources
| where type =~ 'Microsoft.Compute/disks'
| where properties.diskState == 'Unattached'
| project name, resourceGroup, location, subscriptionId, properties.diskSizeGB, properties.timeCreated, id
QUERY
}

resource "azurerm_resource_graph_query" "orphaned_public_ips" {
  count = var.create_orphaned_public_ips_query ? 1 : 0

  name              = var.orphaned_public_ips_query_name
  resource_group_id = var.resource_group_id
  type              = var.query_type
  description       = var.orphaned_public_ips_query_description

  query = var.orphaned_public_ips_query != null ? var.orphaned_public_ips_query : <<QUERY
Resources
| where type =~ 'Microsoft.Network/publicIPAddresses'
| where isnull(properties.ipConfiguration) or properties.ipConfiguration == ''
| project name, resourceGroup, location, subscriptionId, properties.ipAddress, id
QUERY
}

resource "azurerm_resource_graph_query" "orphaned_nics" {
  count = var.create_orphaned_nics_query ? 1 : 0

  name              = var.orphaned_nics_query_name
  resource_group_id = var.resource_group_id
  type              = var.query_type
  description       = var.orphaned_nics_query_description

  query = var.orphaned_nics_query != null ? var.orphaned_nics_query : <<QUERY
Resources
| where type =~ 'Microsoft.Network/networkInterfaces'
| where isnull(properties.virtualMachine) or properties.virtualMachine == ''
| project name, resourceGroup, location, subscriptionId, id
QUERY
}

resource "azurerm_resource_graph_query" "orphaned_storage_accounts" {
  count = var.create_orphaned_storage_accounts_query ? 1 : 0

  name              = var.orphaned_storage_accounts_query_name
  resource_group_id = var.resource_group_id
  type              = var.query_type
  description       = var.orphaned_storage_accounts_query_description

  query = var.orphaned_storage_accounts_query != null ? var.orphaned_storage_accounts_query : <<QUERY
Resources
| where type =~ 'Microsoft.Storage/storageAccounts'
| where properties.provisioningState == 'Succeeded'
| extend containerCount = properties.primaryEndpoints.blob
| project name, resourceGroup, location, subscriptionId, kind, sku.name, id
QUERY
}
