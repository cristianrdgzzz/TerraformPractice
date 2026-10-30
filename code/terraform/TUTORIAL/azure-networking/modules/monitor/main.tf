# ============================================================================
# Azure Monitor Module - Main Configuration
# ============================================================================
# Azure Monitor is a comprehensive monitoring solution for collecting,
# analyzing, and responding to monitoring data from cloud and on-premises
# environments.
#
# Key Features:
# - Log Analytics workspaces
# - Diagnostic settings
# - Metric alerts
# - Log alerts
# - Action groups
# ============================================================================

# ----------------------------------------------------------------------------
# Log Analytics Workspace
# ----------------------------------------------------------------------------
# A Log Analytics workspace is a unique environment for Azure Monitor log data.
# Each workspace has its own data repository and configuration.
# ----------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  count                              = var.create_log_analytics_workspace ? 1 : 0
  name                               = var.log_analytics_workspace_name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  sku                                = var.log_analytics_sku
  retention_in_days                  = var.log_analytics_retention_in_days
  daily_quota_gb                     = var.log_analytics_daily_quota_gb
  internet_ingestion_enabled         = var.log_analytics_internet_ingestion_enabled
  internet_query_enabled             = var.log_analytics_internet_query_enabled
  reservation_capacity_in_gb_per_day = var.log_analytics_reservation_capacity

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Diagnostic Settings
# ----------------------------------------------------------------------------
# Diagnostic settings enable you to collect resource logs and metrics from
# Azure resources and send them to Log Analytics workspace, Storage account,
# or Event Hub.
# ----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "main" {
  for_each = var.diagnostic_settings

  name                           = each.key
  target_resource_id             = each.value.target_resource_id
  log_analytics_workspace_id     = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.main[0].id : each.value.log_analytics_workspace_id
  storage_account_id             = each.value.storage_account_id
  eventhub_name                  = each.value.eventhub_name
  eventhub_authorization_rule_id = each.value.eventhub_authorization_rule_id

  # Log categories
  # Note: retention_policy is deprecated. Retention is managed at the workspace level
  # for Log Analytics or via lifecycle policies for Storage Accounts.
  dynamic "log" {
    for_each = each.value.logs != null ? each.value.logs : {}
    content {
      category = log.key
      enabled  = log.value.enabled
    }
  }

  # Metric categories
  # Note: retention_policy is deprecated. Retention is managed at the workspace level
  # for Log Analytics or via lifecycle policies for Storage Accounts.
  dynamic "metric" {
    for_each = each.value.metrics != null ? each.value.metrics : {}
    content {
      category = metric.key
      enabled  = metric.value.enabled
    }
  }
}

# ----------------------------------------------------------------------------
# Action Groups
# ----------------------------------------------------------------------------
# Action groups define how alerts are notified and what actions are taken
# when alerts are triggered.
# ----------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "main" {
  for_each = var.action_groups

  name                = each.key
  resource_group_name = var.resource_group_name
  short_name          = each.value.short_name
  enabled             = each.value.enabled != null ? each.value.enabled : true

  # Email receivers
  dynamic "email_receiver" {
    for_each = each.value.email_receivers != null ? each.value.email_receivers : []
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = email_receiver.value.use_common_alert_schema != null ? email_receiver.value.use_common_alert_schema : false
    }
  }

  # SMS receivers
  dynamic "sms_receiver" {
    for_each = each.value.sms_receivers != null ? each.value.sms_receivers : []
    content {
      name         = sms_receiver.value.name
      country_code = sms_receiver.value.country_code
      phone_number = sms_receiver.value.phone_number
    }
  }

  # Webhook receivers
  dynamic "webhook_receiver" {
    for_each = each.value.webhook_receivers != null ? each.value.webhook_receivers : []
    content {
      name                    = webhook_receiver.value.name
      service_uri             = webhook_receiver.value.service_uri
      use_common_alert_schema = webhook_receiver.value.use_common_alert_schema != null ? webhook_receiver.value.use_common_alert_schema : false
    }
  }

  # Azure App Push receivers
  dynamic "azure_app_push_receiver" {
    for_each = each.value.azure_app_push_receivers != null ? each.value.azure_app_push_receivers : []
    content {
      name          = azure_app_push_receiver.value.name
      email_address = azure_app_push_receiver.value.email_address
    }
  }

  # Voice receivers
  dynamic "voice_receiver" {
    for_each = each.value.voice_receivers != null ? each.value.voice_receivers : []
    content {
      name         = voice_receiver.value.name
      country_code = voice_receiver.value.country_code
      phone_number = voice_receiver.value.phone_number
    }
  }

  # Logic App receivers
  dynamic "logic_app_receiver" {
    for_each = each.value.logic_app_receivers != null ? each.value.logic_app_receivers : []
    content {
      name                    = logic_app_receiver.value.name
      resource_id             = logic_app_receiver.value.resource_id
      callback_url            = logic_app_receiver.value.callback_url
      use_common_alert_schema = logic_app_receiver.value.use_common_alert_schema != null ? logic_app_receiver.value.use_common_alert_schema : false
    }
  }

  # Azure Function receivers
  dynamic "azure_function_receiver" {
    for_each = each.value.azure_function_receivers != null ? each.value.azure_function_receivers : []
    content {
      name                     = azure_function_receiver.value.name
      function_app_resource_id = azure_function_receiver.value.function_app_resource_id
      function_name            = azure_function_receiver.value.function_name
      http_trigger_url         = azure_function_receiver.value.http_trigger_url
      use_common_alert_schema  = azure_function_receiver.value.use_common_alert_schema != null ? azure_function_receiver.value.use_common_alert_schema : false
    }
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Metric Alerts
# ----------------------------------------------------------------------------
# Metric alerts monitor metric values and trigger when conditions are met.
# They provide near real-time monitoring and are ideal for threshold-based
# scenarios.
# ----------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "main" {
  for_each = var.metric_alerts

  name                = each.key
  resource_group_name = var.resource_group_name
  scopes              = each.value.scopes
  description         = each.value.description
  enabled             = each.value.enabled != null ? each.value.enabled : true
  severity            = each.value.severity != null ? each.value.severity : 3
  frequency           = each.value.frequency != null ? each.value.frequency : "PT1M"
  window_size         = each.value.window_size != null ? each.value.window_size : "PT5M"

  # Criteria
  dynamic "criteria" {
    for_each = each.value.criteria != null ? [each.value.criteria] : []
    content {
      metric_namespace = criteria.value.metric_namespace
      metric_name      = criteria.value.metric_name
      aggregation      = criteria.value.aggregation
      operator         = criteria.value.operator
      threshold        = criteria.value.threshold
    }
  }

  # Dynamic criteria
  dynamic "dynamic_criteria" {
    for_each = each.value.dynamic_criteria != null ? [each.value.dynamic_criteria] : []
    content {
      metric_namespace  = dynamic_criteria.value.metric_namespace
      metric_name       = dynamic_criteria.value.metric_name
      aggregation       = dynamic_criteria.value.aggregation
      operator          = dynamic_criteria.value.operator
      alert_sensitivity = dynamic_criteria.value.alert_sensitivity
    }
  }

  # Actions
  dynamic "action" {
    for_each = each.value.action_group_name != null ? [each.value.action_group_name] : []
    content {
      action_group_id = azurerm_monitor_action_group.main[action.value].id
    }
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Log Alerts (Scheduled Query Rules)
# ----------------------------------------------------------------------------
# Log alerts are based on log query results and are evaluated on a schedule.
# They are ideal for complex conditions and large data volumes.
# ----------------------------------------------------------------------------
resource "azurerm_monitor_scheduled_query_rules_alert" "main" {
  for_each = var.log_alerts

  name                = each.key
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = each.value.description
  enabled             = each.value.enabled != null ? each.value.enabled : true

  data_source_id = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.main[0].id : each.value.log_analytics_workspace_id
  query          = each.value.query
  frequency      = each.value.frequency
  time_window    = each.value.time_window
  severity       = each.value.severity != null ? each.value.severity : 2

  # Trigger
  trigger {
    operator  = each.value.trigger.operator
    threshold = each.value.trigger.threshold
  }

  # Actions
  dynamic "action" {
    for_each = each.value.action_group_name != null ? [each.value.action_group_name] : []
    content {
      action_group = [azurerm_monitor_action_group.main[action.value].id]
    }
  }

  tags = var.tags
}

