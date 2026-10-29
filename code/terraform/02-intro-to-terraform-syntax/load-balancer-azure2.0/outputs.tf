# ============================================================================
# Load Balancer Output Values
# ============================================================================

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer"
  value       = azurerm_public_ip.lb.ip_address
}

output "load_balancer_id" {
  description = "Resource ID of the load balancer"
  value       = azurerm_lb.main.id
}

output "backend_address_pool_id" {
  description = "Resource ID of the backend address pool"
  value       = azurerm_lb_backend_address_pool.main.id
}

output "backend_vm_ids" {
  description = "Resource IDs of backend VMs"
  value       = azurerm_virtual_machine.backend[*].id
}

output "backend_nic_ids" {
  description = "Resource IDs of backend network interfaces"
  value       = azurerm_network_interface.backend[*].id
}

output "backend_private_ips" {
  description = "Private IP addresses of backend servers"
  value       = azurerm_network_interface.backend[*].private_ip_address
}

output "resource_group_name" {
  description = "Name of the Resource Group"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "Resource ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "backend_subnet_id" {
  description = "Resource ID of the backend subnet"
  value       = azurerm_subnet.backend.id
}

output "load_balancer_access_url" {
  description = "URL to access the load balancer"
  value       = "http://${azurerm_public_ip.lb.ip_address}"
}

output "health_probe_id" {
  description = "Resource ID of the health probe"
  value       = azurerm_lb_probe.http.id
}

output "lb_rule_id" {
  description = "Resource ID of the load balancing rule"
  value       = azurerm_lb_rule.http.id
}
