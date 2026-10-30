# ============================================================================
# Azure Monitor Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

# ----------------------------------------------------------------------------
# Log Analytics Workspace
# ----------------------------------------------------------------------------
variable "create_log_analytics_workspace" {
  description = "Whether to create a Log Analytics workspace"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace (must be globally unique)"
  type        = string
  default     = null
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspace. Options: 'Free', 'PerNode', 'PerGB2018', 'Standard', 'Premium', 'CapacityReservation'"
  type        = string
  default     = "PerGB2018"
  validation {
    condition     = contains(["Free", "PerNode", "PerGB2018", "Standard", "Premium", "CapacityReservation"], var.log_analytics_sku)
    error_message = "Log Analytics SKU must be one of: Free, PerNode, PerGB2018, Standard, Premium, CapacityReservation."
  }
}

variable "log_analytics_retention_in_days" {
  description = "Data retention in days (30-730, or null for unlimited)"
  type        = number
  default     = 30
}

variable "log_analytics_daily_quota_gb" {
  description = "Daily quota for data ingestion in GB (optional)"
  type        = number
  default     = null
}

variable "log_analytics_internet_ingestion_enabled" {
  description = "Enable internet ingestion for Log Analytics workspace"
  type        = bool
  default     = false
}

variable "log_analytics_internet_query_enabled" {
  description = "Enable internet query for Log Analytics workspace"
  type        = bool
  default     = false
}

variable "log_analytics_reservation_capacity" {
  description = "Reservation capacity in GB per day (for CapacityReservation SKU)"
  type        = number
  default     = null
}

# ----------------------------------------------------------------------------
# Diagnostic Settings
# ----------------------------------------------------------------------------
variable "diagnostic_settings" {
  description = <<-EOT
    Map of diagnostic settings to create.
    
    Example:
    diagnostic_settings = {
      vnet = {
        target_resource_id = azurerm_virtual_network.main.id
        logs = {
          VMProtectionAlerts = {
            enabled = true
          }
        }
        metrics = {
          AllMetrics = {
            enabled = true
          }
        }
      }
    }
  EOT
  type = map(object({
    target_resource_id             = string
    log_analytics_workspace_id     = optional(string, null)
    storage_account_id             = optional(string, null)
    eventhub_name                  = optional(string, null)
    eventhub_authorization_rule_id = optional(string, null)
    logs = optional(map(object({
      enabled = bool
      # Note: retention_policy is deprecated. Retention is managed at the workspace level
      # for Log Analytics (via log_analytics_retention_in_days) or via lifecycle policies
      # for Storage Accounts.
    })), {})
    metrics = optional(map(object({
      enabled = bool
      # Note: retention_policy is deprecated. Retention is managed at the workspace level
      # for Log Analytics (via log_analytics_retention_in_days) or via lifecycle policies
      # for Storage Accounts.
    })), {})
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Action Groups
# ----------------------------------------------------------------------------
variable "action_groups" {
  description = <<-EOT
    Map of action groups to create.
    
    Example:
    action_groups = {
      production = {
        short_name = "prod-alerts"
        email_receivers = [
          {
            name          = "admin"
            email_address = "admin@example.com"
          }
        ]
      }
    }
  EOT
  type = map(object({
    short_name = string
    enabled    = optional(bool, true)
    email_receivers = optional(list(object({
      name                    = string
      email_address           = string
      use_common_alert_schema = optional(bool, false)
    })), [])
    sms_receivers = optional(list(object({
      name         = string
      country_code = string
      phone_number = string
    })), [])
    webhook_receivers = optional(list(object({
      name                    = string
      service_uri             = string
      use_common_alert_schema = optional(bool, false)
    })), [])
    azure_app_push_receivers = optional(list(object({
      name          = string
      email_address = string
    })), [])
    voice_receivers = optional(list(object({
      name         = string
      country_code = string
      phone_number = string
    })), [])
    logic_app_receivers = optional(list(object({
      name                    = string
      resource_id             = string
      callback_url            = string
      use_common_alert_schema = optional(bool, false)
    })), [])
    azure_function_receivers = optional(list(object({
      name                     = string
      function_app_resource_id = string
      function_name            = string
      http_trigger_url         = string
      use_common_alert_schema  = optional(bool, false)
    })), [])
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Metric Alerts
# ----------------------------------------------------------------------------
variable "metric_alerts" {
  description = <<-EOT
    Map of metric alerts to create.
    
    Example:
    metric_alerts = {
      cpu_alert = {
        description = "Alert when CPU exceeds 80%"
        scopes      = [azurerm_virtual_machine.main.id]
        criteria = {
          metric_namespace = "Microsoft.Compute/virtualMachines"
          metric_name      = "Percentage CPU"
          aggregation      = "Average"
          operator         = "GreaterThan"
          threshold        = 80
        }
        action_group_name = "production"
      }
    }
  EOT
  type = map(object({
    description = optional(string, "")
    scopes      = list(string)
    enabled     = optional(bool, true)
    severity    = optional(number, 3)
    frequency   = optional(string, "PT1M")
    window_size = optional(string, "PT5M")
    criteria = optional(object({
      metric_namespace = string
      metric_name      = string
      aggregation      = string
      operator         = string
      threshold        = number
    }), null)
    dynamic_criteria = optional(object({
      metric_namespace  = string
      metric_name       = string
      aggregation       = string
      operator          = string
      alert_sensitivity = string
    }), null)
    action_group_name = optional(string, null)
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Log Alerts
# ----------------------------------------------------------------------------
variable "log_alerts" {
  description = <<-EOT
    Map of log alerts (scheduled query rules) to create.
    
    Example:
    log_alerts = {
      error_alert = {
        description = "Alert on error count"
        query       = "Event | where EventLevelName == 'Error' | summarize count() by bin(TimeGenerated, 5m)"
        frequency   = 5
        time_window = 5
        trigger = {
          operator  = "GreaterThan"
          threshold = 10
        }
        action_group_name = "production"
      }
    }
  EOT
  type = map(object({
    description                = optional(string, "")
    log_analytics_workspace_id = optional(string, null)
    query                      = string
    frequency                  = number
    time_window                = number
    severity                   = optional(number, 2)
    enabled                    = optional(bool, true)
    trigger = object({
      operator  = string
      threshold = number
    })
    action_group_name = optional(string, null)
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Tags
# ----------------------------------------------------------------------------
variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}

