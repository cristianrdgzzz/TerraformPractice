# ============================================================================
# Virtual Network Module - Outputs
# ============================================================================
# Outputs expose important resource information for use by other modules
# or for reference in other Terraform configurations.
# ============================================================================

output "vnet_id" {
  description = "The ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_address_space" {
  description = "The address space of the Virtual Network"
  value       = azurerm_virtual_network.main.address_space
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value = {
    for k, v in azurerm_subnet.main : k => v.id
  }
}

output "subnet_address_prefixes" {
  description = "Map of subnet names to their address prefixes"
  value = {
    for k, v in azurerm_subnet.main : k => v.address_prefixes
  }
}

output "network_security_group_ids" {
  description = "Map of NSG names to their IDs"
  value = {
    for k, v in azurerm_network_security_group.main : k => v.id
  }
}

output "route_table_ids" {
  description = "Map of route table names to their IDs"
  value = {
    for k, v in azurerm_route_table.main : k => v.id
  }
}

output "subnet_details" {
  description = "Detailed information about all subnets"
  value = {
    for k, v in azurerm_subnet.main : k => {
      id                = v.id
      name              = v.name
      address_prefixes  = v.address_prefixes
      service_endpoints = v.service_endpoints
      has_delegation    = v.delegation != null && length(v.delegation) > 0
    }
  }
}

