# ============================================================================
# Azure Firewall Manager Module - Variables
# ============================================================================
# Firewall Manager provides centralized security policy management for
# Azure Firewall and partner security solutions.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "firewall_policy_name" {
  description = "Name of the Firewall Policy"
  type        = string
}

variable "sku" {
  description = "Firewall Policy SKU. Options: 'Standard' or 'Premium'"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.sku)
    error_message = "SKU must be either 'Standard' or 'Premium'."
  }
}

variable "threat_intelligence_mode" {
  description = "Threat Intelligence mode. Options: 'Off', 'Alert', 'Deny'"
  type        = string
  default     = "Alert"

  validation {
    condition     = contains(["Off", "Alert", "Deny"], var.threat_intelligence_mode)
    error_message = "Threat Intelligence mode must be one of: Off, Alert, Deny."
  }
}

variable "threat_intelligence_allowlist" {
  description = "List of IP addresses/ranges to allowlist in Threat Intelligence"
  type        = list(string)
  default     = []
}

variable "dns_settings" {
  description = <<-EOT
    DNS settings for the firewall policy.
    
    Example:
    dns_settings = {
      servers                 = []
      proxy_enabled           = false
      network_rule_fqdn_enabled = false
    }
  EOT
  type = object({
    servers                   = optional(list(string), [])
    proxy_enabled             = optional(bool, false)
    network_rule_fqdn_enabled = optional(bool, false)
  })
  default = {
    servers                   = []
    proxy_enabled             = false
    network_rule_fqdn_enabled = false
  }
}

variable "rule_collection_groups" {
  description = <<-EOT
    Map of rule collection groups.
    Rule collection groups organize firewall rules for easier management.
    
    Example:
    rule_collection_groups = {
      "network-rules" = {
        priority = 100
        network_rule_collections = [
          {
            name     = "AllowHTTPS"
            priority = 100
            action   = "Allow"
            rules = [
              {
                name                  = "AllowHTTPS"
                protocols             = ["TCP"]
                source_addresses      = ["*"]
                destination_addresses = ["*"]
                destination_ports     = ["443"]
              }
            ]
          }
        ]
      }
    }
  EOT
  type = map(object({
    priority = number
    network_rule_collections = optional(list(object({
      name     = string
      priority = number
      action   = string
      rules = list(object({
        name                  = string
        protocols             = list(string)
        source_addresses      = list(string)
        destination_addresses = optional(list(string), [])
        destination_fqdns     = optional(list(string), [])
        destination_ports     = list(string)
      }))
    })), [])
    application_rule_collections = optional(list(object({
      name     = string
      priority = number
      action   = string
      rules = list(object({
        name             = string
        source_addresses = list(string)
        protocols = list(object({
          type = string
          port = number
        }))
        target_fqdns     = optional(list(string), [])
        fqdn_tags        = optional(list(string), [])
        source_ip_groups = optional(list(string), [])
      }))
    })), [])
    nat_rule_collections = optional(list(object({
      name     = string
      priority = number
      action   = string
      rules = list(object({
        name                = string
        protocols           = list(string)
        source_addresses    = list(string)
        destination_address = string
        destination_ports   = list(string)
        translated_address  = string
        translated_port     = number
      }))
    })), [])
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

