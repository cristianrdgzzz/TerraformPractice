# ============================================================================
# Azure Load Balancer Module - Outputs
# ============================================================================

output "load_balancer_id" {
  description = "The ID of the Load Balancer"
  value       = azurerm_lb.main.id
}

output "load_balancer_name" {
  description = "The name of the Load Balancer"
  value       = azurerm_lb.main.name
}

output "frontend_ip_configurations" {
  description = "Map of frontend IP configuration names to their details"
  value = {
    for fe in azurerm_lb.main.frontend_ip_configuration : fe.name => {
      id                   = fe.id
      name                 = fe.name
      private_ip_address   = fe.private_ip_address
      public_ip_address_id = fe.public_ip_address_id
    }
  }
}

output "backend_address_pool_ids" {
  description = "Map of backend address pool names to their IDs"
  value = {
    for k, v in azurerm_lb_backend_address_pool.main : k => v.id
  }
}

output "probe_ids" {
  description = "Map of probe names to their IDs"
  value = {
    for k, v in azurerm_lb_probe.main : k => v.id
  }
}

output "load_balancing_rule_ids" {
  description = "Map of load balancing rule names to their IDs"
  value = {
    for k, v in azurerm_lb_rule.main : k => v.id
  }
}

output "outbound_rule_ids" {
  description = "Map of outbound rule names to their IDs"
  value = {
    for k, v in azurerm_lb_outbound_rule.main : k => v.id
  }
}

output "inbound_nat_rule_ids" {
  description = "Map of inbound NAT rule names to their IDs"
  value = {
    for k, v in azurerm_lb_nat_rule.main : k => v.id
  }
}

