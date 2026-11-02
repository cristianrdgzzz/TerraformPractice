output "lb_public_ip" {
  description = "IP pública del balanceador de carga"
  value       = azurerm_public_ip.lb.ip_address
}
