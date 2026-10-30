# ============================================================================
# Azure Network Watcher Module - Variables
# ============================================================================
# Network Watcher provides tools to monitor, diagnose, and view metrics
# for your Azure network infrastructure.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region (Network Watcher must be in the same region as resources being monitored)"
  type        = string
}

variable "network_watcher_name" {
  description = "Name of the Network Watcher (typically 'NetworkWatcher_{region}')"
  type        = string
  default     = null
}

variable "enable_flow_logs" {
  description = "Enable NSG flow logs"
  type        = bool
  default     = false
}

variable "flow_logs" {
  description = <<-EOT
    Map of NSG flow logs to create.
    
    Example:
    flow_logs = {
      "nsg-web-flow-log" = {
        network_security_group_id = azurerm_network_security_group.web.id
        storage_account_id        = azurerm_storage_account.logs.id
        enabled                   = true
        retention_days            = 30
        version                   = 2
      }
    }
  EOT
  type = map(object({
    network_security_group_id = string
    storage_account_id        = string
    enabled                   = optional(bool, true)
    retention_days            = optional(number, 0)
    version                   = optional(number, 2)
    traffic_analytics = optional(object({
      enabled               = bool
      workspace_id          = string
      workspace_region      = string
      workspace_resource_id = string
      interval_in_minutes   = optional(number, 60)
    }), null)
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "connection_monitors" {
  description = <<-EOT
    Map of connection monitors to create.
    Connection monitors test connectivity between endpoints.
    
    Example:
    connection_monitors = {
      "web-to-db" = {
        name = "cm-web-to-db"
        source = {
          virtual_machine_id = azurerm_virtual_machine.web.id
        }
        destination = {
          address = "10.0.3.10"
          port    = 1433
        }
        test_configurations = [
          {
            name                      = "tcp-test"
            protocol                  = "Tcp"
            test_frequency_in_seconds = 60
            preferred_ip_version      = "IPv4"
            tcp_configuration = {
              port                      = 1433
              disable_trace_route       = false
            }
          }
        ]
      }
    }
  EOT
  type = map(object({
    name  = string
    notes = optional(string, null)
    source = object({
      virtual_machine_id = optional(string, null)
      address            = optional(string, null)
    })
    destination = object({
      address = string
    })
    test_configurations = list(object({
      name                      = string
      protocol                  = string # "Tcp", "Http", "Icmp"
      test_frequency_in_seconds = number
      preferred_ip_version      = optional(string, "IPv4")
      tcp_configuration = optional(object({
        port                = number
        disable_trace_route = optional(bool, false)
      }), null)
      http_configuration = optional(object({
        port                     = number
        method                   = optional(string, "Get")
        path                     = optional(string, "/")
        request_headers          = optional(map(string), {})
        valid_status_code_ranges = optional(list(string), ["200-299"])
        prefer_https             = optional(bool, false)
      }), null)
      icmp_configuration = optional(object({
        disable_trace_route = optional(bool, false)
      }), null)
    }))
    enabled = optional(bool, true)
    tags    = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

