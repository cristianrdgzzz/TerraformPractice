# ============================================================================
# Azure Virtual Network Manager Example - Outputs
# ============================================================================
# Outputs expose important information about the created resources
# ============================================================================

# ----------------------------------------------------------------------------
# Network Manager Outputs
# ----------------------------------------------------------------------------
output "network_manager_id" {
  description = "ID of the Network Manager instance"
  value       = module.network_manager_subscription.network_manager_id
}

output "network_manager_name" {
  description = "Name of the Network Manager instance"
  value       = module.network_manager_subscription.network_manager_name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.network_manager_subscription.resource_group_name
}

# ----------------------------------------------------------------------------
# Network Groups Outputs
# ----------------------------------------------------------------------------
output "network_group_ids" {
  description = "Map of network group names to their IDs"
  value       = module.network_manager_subscription.network_group_ids
}

output "network_group_details" {
  description = "Detailed information about all network groups"
  value       = module.network_manager_subscription.network_group_details
}

# ----------------------------------------------------------------------------
# Connectivity Configuration Outputs
# ----------------------------------------------------------------------------
output "connectivity_configuration_ids" {
  description = "Map of connectivity configuration names to their IDs"
  value       = module.network_manager_subscription.connectivity_configuration_ids
}

# ----------------------------------------------------------------------------
# Security Admin Configuration Outputs
# ----------------------------------------------------------------------------
output "security_admin_configuration_ids" {
  description = "Map of security admin configuration names to their IDs"
  value       = module.network_manager_subscription.security_admin_configuration_ids
}

output "admin_rule_collection_ids" {
  description = "Map of security admin rule collection names to their IDs"
  value       = module.network_manager_subscription.admin_rule_collection_ids
}

output "admin_rule_ids" {
  description = "Map of security admin rule names to their IDs"
  value       = module.network_manager_subscription.admin_rule_ids
}

# ----------------------------------------------------------------------------
# Routing Configuration Outputs
# ----------------------------------------------------------------------------
output "routing_configuration_ids" {
  description = "Map of routing configuration names to their IDs"
  value       = module.network_manager_subscription.routing_configuration_ids
}

output "routing_rule_collection_ids" {
  description = "Map of routing rule collection names to their IDs"
  value       = module.network_manager_subscription.routing_rule_collection_ids
}

output "routing_rule_ids" {
  description = "Map of routing rule names to their IDs"
  value       = module.network_manager_subscription.routing_rule_ids
}

# ----------------------------------------------------------------------------
# Deployment Outputs
# ----------------------------------------------------------------------------
output "deployment_ids" {
  description = "Map of deployment names to their IDs"
  value       = module.network_manager_subscription.deployment_ids
}

# ----------------------------------------------------------------------------
# Summary Output
# ----------------------------------------------------------------------------
output "summary" {
  description = "Summary of created resources"
  value = {
    network_manager_name       = module.network_manager_subscription.network_manager_name
    network_groups_count       = length(module.network_manager_subscription.network_group_ids)
    connectivity_configs_count = length(module.network_manager_subscription.connectivity_configuration_ids)
    security_configs_count     = length(module.network_manager_subscription.security_admin_configuration_ids)
    routing_configs_count      = length(module.network_manager_subscription.routing_configuration_ids)
    deployments_count          = length(module.network_manager_subscription.deployment_ids)
  }
}

