# ============================================================================
# Azure FinOps Budget Guardrails Module - Main Configuration
# ============================================================================
# This module creates automated budget alerts for resource groups or subscriptions,
# enabling proactive cost management and decentralized accountability.
#
# Key Features:
# - Configurable budget thresholds (50%, 80%, 100%)
# - Multiple notification channels (Email, SMS, Webhook, Azure Functions)
# - Support for existing Action Groups from centralized modules
# - Flexible time grains (Monthly, Quarterly, Annually)
# - Forecasted and actual cost alerts
# ============================================================================

# ----------------------------------------------------------------------------
# Action Group Configuration
# ----------------------------------------------------------------------------
# OPTION 1: Create a new Action Group (default behavior)
# This is useful for standalone deployments or team-specific alerting.
# ----------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "budget" {
  count = var.create_action_group ? 1 : 0

  name                = var.action_group_name != null ? var.action_group_name : "finops-budget-alerts-${var.budget_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  short_name          = var.action_group_short_name
  enabled             = true

  # Email receivers
  dynamic "email_receiver" {
    for_each = var.email_receivers
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = email_receiver.value.use_common_alert_schema != null ? email_receiver.value.use_common_alert_schema : false
    }
  }

  # SMS receivers
  dynamic "sms_receiver" {
    for_each = var.sms_receivers
    content {
      name         = sms_receiver.value.name
      country_code = sms_receiver.value.country_code
      phone_number = sms_receiver.value.phone_number
    }
  }

  # Webhook receivers
  dynamic "webhook_receiver" {
    for_each = var.webhook_receivers
    content {
      name                    = webhook_receiver.value.name
      service_uri             = webhook_receiver.value.service_uri
      use_common_alert_schema = webhook_receiver.value.use_common_alert_schema != null ? webhook_receiver.value.use_common_alert_schema : false
      aad_auth {
        object_id      = webhook_receiver.value.aad_auth.object_id
        identifier_uri = webhook_receiver.value.aad_auth.identifier_uri
        tenant_id      = webhook_receiver.value.aad_auth.tenant_id
      }
    }
  }

  # Azure Function receivers
  dynamic "azure_function_receiver" {
    for_each = var.azure_function_receivers
    content {
      name                     = azure_function_receiver.value.name
      function_app_resource_id = azure_function_receiver.value.function_app_resource_id
      function_name            = azure_function_receiver.value.function_name
      http_trigger_url         = azure_function_receiver.value.http_trigger_url
      use_common_alert_schema  = azure_function_receiver.value.use_common_alert_schema != null ? azure_function_receiver.value.use_common_alert_schema : false
    }
  }

  tags = merge(
    var.tags,
    {
      Purpose     = "FinOps-BudgetAlerts"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# OPTION 2: Reference an existing Action Group via data source
# ----------------------------------------------------------------------------
# If you have a centralized action group managed by a shared-services module,
# use this data source instead of creating a new one:
#
# data "azurerm_monitor_action_group" "existing" {
#   count = var.create_action_group ? 0 : 1
#   name                = var.existing_action_group_name
#   resource_group_name = var.existing_action_group_resource_group_name
# }
#
# Then reference it in the budget resource:
# contact_groups = var.create_action_group ? [azurerm_monitor_action_group.budget[0].id] : [data.azurerm_monitor_action_group.existing[0].id]
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# OPTION 3: Reference an Action Group created by a module
# ----------------------------------------------------------------------------
# If you're using a centralized monitor/action-group module (e.g., from a shared
# infrastructure repository), you can pass the action group ID directly:
#
# module "shared_monitor" {
#   source = "git::https://github.com/org/terraform-azurerm-monitor.git"
#   # ... action group configuration
# }
#
# module "budget" {
#   source = "./modules/finops-budget-guardrails"
#   # ... other variables
#   create_action_group = false
#   existing_action_group_id = module.shared_monitor.action_group_id
# }
#
# This approach is recommended for enterprise environments where action groups
# are managed centrally for consistency, compliance, and maintenance.
# ----------------------------------------------------------------------------

# Local value to determine which action group ID to use
locals {
  action_group_id = var.create_action_group ? azurerm_monitor_action_group.budget[0].id : var.existing_action_group_id
}

# ----------------------------------------------------------------------------
# Consumption Budget Configuration
# ----------------------------------------------------------------------------
resource "azurerm_consumption_budget_resource_group" "budget" {
  count = var.budget_scope == "resource_group" ? 1 : 0

  name              = var.budget_name
  resource_group_id = var.resource_group_id

  amount     = var.budget_amount
  time_grain = var.time_grain

  time_period {
    start_date = var.time_period_start_date != null ? var.time_period_start_date : formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
    end_date   = var.time_period_end_date
  }

  # Dynamic notifications based on configuration
  dynamic "notification" {
    for_each = var.notifications
    content {
      enabled        = notification.value.enabled
      threshold      = notification.value.threshold
      threshold_type = notification.value.threshold_type != null ? notification.value.threshold_type : "Actual"
      operator       = notification.value.operator
      contact_groups = [local.action_group_id]
      contact_emails = notification.value.contact_emails != null ? notification.value.contact_emails : []
    }
  }

  # Filter by resource tags (optional)
  dynamic "filter" {
    for_each = var.filter_tags != null ? [var.filter_tags] : []
    content {
      dynamic "tag" {
        for_each = filter.value
        content {
          name   = tag.key
          values = tag.value
        }
      }
    }
  }
}

# Subscription-level budget (alternative scope)
resource "azurerm_consumption_budget_subscription" "budget" {
  count = var.budget_scope == "subscription" ? 1 : 0

  name            = var.budget_name
  subscription_id = var.subscription_id

  amount     = var.budget_amount
  time_grain = var.time_grain

  time_period {
    start_date = var.time_period_start_date != null ? var.time_period_start_date : formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
    end_date   = var.time_period_end_date
  }

  # Dynamic notifications based on configuration
  dynamic "notification" {
    for_each = var.notifications
    content {
      enabled        = notification.value.enabled
      threshold      = notification.value.threshold
      threshold_type = notification.value.threshold_type != null ? notification.value.threshold_type : "Actual"
      operator       = notification.value.operator
      contact_groups = [local.action_group_id]
      contact_emails = notification.value.contact_emails != null ? notification.value.contact_emails : []
    }
  }

  # Filter by resource tags (optional)
  dynamic "filter" {
    for_each = var.filter_tags != null ? [var.filter_tags] : []
    content {
      dynamic "tag" {
        for_each = filter.value
        content {
          name   = tag.key
          values = tag.value
        }
      }
    }
  }
}
