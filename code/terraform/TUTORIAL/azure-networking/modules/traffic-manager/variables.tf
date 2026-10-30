# ============================================================================
# Azure Traffic Manager Module - Variables
# ============================================================================
# Traffic Manager is a DNS-based traffic load balancer that distributes
# traffic to endpoints based on routing methods.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region (typically 'global' for Traffic Manager)"
  type        = string
  default     = "global"
}

variable "traffic_manager_profile_name" {
  description = "Name of the Traffic Manager profile"
  type        = string
}

variable "traffic_routing_method" {
  description = <<-EOT
    Traffic routing method. Options:
    - Priority: Failover (primary → secondary)
    - Weighted: Distribute by weight percentage
    - Performance: Route to lowest latency endpoint
    - Geographic: Route based on user location
    - Subnet: Route based on source IP subnet
    - MultiValue: Return multiple healthy endpoints
  EOT
  type        = string
  default     = "Performance"

  validation {
    condition = contains([
      "Priority",
      "Weighted",
      "Performance",
      "Geographic",
      "Subnet",
      "MultiValue"
    ], var.traffic_routing_method)
    error_message = "Traffic routing method must be one of: Priority, Weighted, Performance, Geographic, Subnet, MultiValue."
  }
}

variable "dns_config" {
  description = <<-EOT
    DNS configuration for the Traffic Manager profile.
    
    Example:
    dns_config = {
      relative_name = "myapp"  # Creates: myapp.trafficmanager.net
      ttl           = 60
    }
  EOT
  type = object({
    relative_name = string
    ttl           = number
  })
}

variable "monitor_config" {
  description = <<-EOT
    Health monitor configuration.
    
    Example:
    monitor_config = {
      protocol                     = "HTTPS"
      port                         = 443
      path                         = "/health"
      interval_in_seconds           = 30
      timeout_in_seconds            = 10
      tolerated_number_of_failures = 3
    }
  EOT
  type = object({
    protocol                     = string # "HTTP", "HTTPS", "TCP"
    port                         = number
    path                         = optional(string, "/")
    interval_in_seconds          = number
    timeout_in_seconds           = number
    tolerated_number_of_failures = number
    expected_status_code_ranges  = optional(list(string), ["200-299"])
  })
}

variable "endpoints" {
  description = <<-EOT
    List of endpoints for the Traffic Manager profile.
    
    Example:
    endpoints = [
      {
        name                    = "east-us-endpoint"
        type                    = "azureEndpoints"
        target_resource_id      = azurerm_public_ip.east.id
        priority                = 1
        weight                  = 50
        enabled                 = true
        geo_mappings            = []
        subnet_ids              = []
        custom_headers          = []
      },
      {
        name                    = "west-europe-endpoint"
        type                    = "azureEndpoints"
        target_resource_id      = azurerm_public_ip.west.id
        priority                = 2
        weight                  = 50
        enabled                 = true
      }
    ]
  EOT
  type = list(object({
    name               = string
    type               = string # "azureEndpoints", "externalEndpoints", "nestedEndpoints"
    target_resource_id = optional(string, null)
    target             = optional(string, null) # For external endpoints
    priority           = optional(number, null)
    weight             = optional(number, null)
    enabled            = optional(bool, true)
    geo_mappings       = optional(list(string), [])
    subnet_ids         = optional(list(string), [])
    custom_headers = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = []
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

