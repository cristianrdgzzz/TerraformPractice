# ============================================================================
# Azure Private Link Module - Variables
# ============================================================================
# Private Link provides private connectivity to Azure services and
# customer-owned services without exposing them to the Internet.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "private_endpoints" {
  description = <<-EOT
    Map of private endpoints to create.
    Private endpoints provide private IP addresses for Azure services.
    
    Example:
    private_endpoints = {
      "storage-endpoint" = {
        name                          = "pe-storage"
        subnet_id                     = azurerm_subnet.private_endpoints.id
        private_service_connection = {
          name                           = "storage-connection"
          private_connection_resource_id = azurerm_storage_account.main.id
          subresource_names              = ["blob"]
          is_manual_connection            = false
        }
        private_dns_zone_group = {
          name                 = "storage-dns-zone-group"
          private_dns_zone_ids = [azurerm_private_dns_zone.storage.id]
        }
      }
    }
  EOT
  type = map(object({
    name      = string
    subnet_id = string
    private_service_connection = object({
      name                           = string
      private_connection_resource_id = string
      subresource_names              = list(string) # e.g., ["blob", "table", "queue", "file"]
      is_manual_connection           = bool
      request_message                = optional(string, null)
    })
    private_dns_zone_group = optional(object({
      name                 = string
      private_dns_zone_ids = list(string)
    }), null)
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "private_link_services" {
  description = <<-EOT
    Map of private link services to create.
    Private link services expose your own services via Private Link.
    
    Example:
    private_link_services = {
      "app-service" = {
        name                = "pls-app"
        load_balancer_frontend_ip_configuration_ids = [azurerm_lb.main.frontend_ip_configuration[0].id]
        nat_ip_configurations = [
          {
            name                       = "nat-ip-1"
            private_ip_address_version = "IPv4"
            subnet_id                  = azurerm_subnet.nat.id
            primary                    = true
          }
        ]
      }
    }
  EOT
  type = map(object({
    name                                        = string
    load_balancer_frontend_ip_configuration_ids = list(string)
    nat_ip_configurations = list(object({
      name                       = string
      private_ip_address_version = string # "IPv4" or "IPv6"
      subnet_id                  = string
      primary                    = bool
    }))
    auto_approval_subscription_ids = optional(list(string), [])
    visibility_subscription_ids    = optional(list(string), [])
    tags                           = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default     = {}
}

