# ============================================================================
# Azure Virtual Network Manager Module - Outputs
# ============================================================================
# Outputs expose important resource information for use by other modules
# or for reference in other Terraform configurations.
# ============================================================================

output "network_manager_id" {
  description = "The ID of the Network Manager instance"
  value       = azurerm_network_manager.main.id
}

output "network_manager_name" {
  description = "The name of the Network Manager instance"
  value       = azurerm_network_manager.main.name
}

output "network_group_ids" {
  description = "Map of network group names to their IDs"
  value = {
    for k, v in azurerm_network_manager_network_group.main : k => v.id
  }
}

output "connectivity_configuration_ids" {
  description = "Map of connectivity configuration names to their IDs"
  value = {
    for k, v in azurerm_network_manager_connectivity_configuration.main : k => v.id
  }
}

output "security_admin_configuration_ids" {
  description = "Map of security admin configuration names to their IDs"
  value = {
    for k, v in azurerm_network_manager_security_admin_configuration.main : k => v.id
  }
}

output "routing_configuration_ids" {
  description = "Map of routing configuration names to their IDs"
  value = {
    for k, v in azurerm_network_manager_routing_configuration.main : k => v.id
  }
}

output "deployment_ids" {
  description = "Map of deployment names to their IDs"
  value = {
    for k, v in azurerm_network_manager_deployment.main : k => v.id
  }
}

output "network_group_details" {
  description = "Detailed information about all network groups"
  value = {
    for k, v in azurerm_network_manager_network_group.main : k => {
      id          = v.id
      name        = v.name
      description = v.description
    }
  }
}

output "connectivity_configuration_details" {
  description = "Detailed information about all connectivity configurations"
  value = {
    for k, v in azurerm_network_manager_connectivity_configuration.main : k => {
      id                              = v.id
      name                            = v.name
      connectivity_topology           = v.connectivity_topology
      applies_to_group_ids            = v.applies_to_group_ids
      delete_existing_peering_enabled = v.delete_existing_peering_enabled
    }
  }
}

output "routing_rule_collection_ids" {
  description = "Map of routing rule collection names to their IDs"
  value = {
    for k, v in azurerm_network_manager_routing_rule_collection.main : k => v.id
  }
}

output "routing_rule_ids" {
  description = "Map of routing rule names to their IDs"
  value = {
    for k, v in azurerm_network_manager_routing_rule.main : k => v.id
  }
}

output "admin_rule_collection_ids" {
  description = "Map of security admin rule collection names to their IDs"
  value = {
    for k, v in azurerm_network_manager_admin_rule_collection.main : k => v.id
  }
}

output "admin_rule_ids" {
  description = "Map of security admin rule names to their IDs"
  value = {
    for k, v in azurerm_network_manager_admin_rule.main : k => v.id
  }
}

output "resource_group_name" {
  description = "Name of the resource group (created or existing)"
  value       = try(module.resource_group[0].resource_group_name, var.resource_group_name)
}

output "resource_group_id" {
  description = "ID of the resource group (created or existing)"
  value       = try(module.resource_group[0].resource_group_id, null)
}

