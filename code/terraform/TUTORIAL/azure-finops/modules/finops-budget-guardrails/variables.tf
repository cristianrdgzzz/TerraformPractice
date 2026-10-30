# ============================================================================
# Azure FinOps Budget Guardrails Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group to create the Action Group in (only used if create_action_group is true)."
  type        = string
  default     = null
}

variable "resource_group_id" {
  description = "ID of the resource group to apply the budget to (required if budget_scope is 'resource_group'). Format: /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}"
  type        = string
  default     = null
}

variable "subscription_id" {
  description = "ID of the subscription to apply the budget to (required if budget_scope is 'subscription'). Format: /subscriptions/{subscription-id}"
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region where the Action Group will be created."
  type        = string
  default     = "global"
}

variable "budget_scope" {
  description = "Scope of the budget. Options: 'resource_group' or 'subscription'."
  type        = string
  default     = "resource_group"
  validation {
    condition     = contains(["resource_group", "subscription"], var.budget_scope)
    error_message = "Budget scope must be 'resource_group' or 'subscription'."
  }
}

variable "budget_name" {
  description = "Name of the budget."
  type        = string
  default     = null
}

variable "budget_amount" {
  description = "The budget amount in the currency of the subscription."
  type        = number
  validation {
    condition     = var.budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "time_grain" {
  description = "The time covered by a budget. Options: 'Monthly', 'Quarterly', 'Annually', 'BillingMonth', 'BillingQuarter', 'BillingYear'."
  type        = string
  default     = "Monthly"
  validation {
    condition     = contains(["Monthly", "Quarterly", "Annually", "BillingMonth", "BillingQuarter", "BillingYear"], var.time_grain)
    error_message = "Time grain must be one of: Monthly, Quarterly, Annually, BillingMonth, BillingQuarter, BillingYear."
  }
}

variable "time_period_start_date" {
  description = "Start date for the budget period in ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ). If null, uses first day of current month."
  type        = string
  default     = null
}

variable "time_period_end_date" {
  description = "End date for the budget period in ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ). If null, budget continues indefinitely."
  type        = string
  default     = null
}

# Action Group Configuration
variable "create_action_group" {
  description = "Whether to create a new Action Group. Set to false to use an existing one."
  type        = bool
  default     = true
}

variable "existing_action_group_id" {
  description = "ID of an existing Action Group to use (required if create_action_group is false). Can reference an action group from a module output."
  type        = string
  default     = null
}

variable "existing_action_group_name" {
  description = "Name of an existing Action Group (optional, used for data source lookup)."
  type        = string
  default     = null
}

variable "existing_action_group_resource_group_name" {
  description = "Resource group name of an existing Action Group (optional, used for data source lookup)."
  type        = string
  default     = null
}

variable "action_group_name" {
  description = "Name of the Action Group to create (only used if create_action_group is true). If null, auto-generated."
  type        = string
  default     = null
}

variable "action_group_short_name" {
  description = "Short name of the Action Group (max 12 characters)."
  type        = string
  default     = "BudgetAlert"
  validation {
    condition     = length(var.action_group_short_name) <= 12
    error_message = "Action group short name must be 12 characters or less."
  }
}

# Email Receivers
variable "email_receivers" {
  description = "List of email receivers for the Action Group."
  type = list(object({
    name                    = string
    email_address           = string
    use_common_alert_schema = optional(bool, false)
  }))
  default = []
}

# SMS Receivers
variable "sms_receivers" {
  description = "List of SMS receivers for the Action Group."
  type = list(object({
    name         = string
    country_code = string
    phone_number = string
  }))
  default = []
}

# Webhook Receivers
variable "webhook_receivers" {
  description = "List of webhook receivers for the Action Group (e.g., Slack, Teams, PagerDuty)."
  type = list(object({
    name                    = string
    service_uri             = string
    use_common_alert_schema = optional(bool, false)
    aad_auth = object({
      object_id      = string
      identifier_uri = string
      tenant_id      = string
    })
  }))
  default = []
}

# Azure Function Receivers
variable "azure_function_receivers" {
  description = "List of Azure Function receivers for the Action Group."
  type = list(object({
    name                     = string
    function_app_resource_id = string
    function_name            = string
    http_trigger_url         = string
    use_common_alert_schema  = optional(bool, false)
  }))
  default = []
}

# Budget Notifications
variable "notifications" {
  description = "List of budget notifications with thresholds and operators."
  type = list(object({
    enabled        = bool
    threshold      = number
    threshold_type = optional(string, "Actual") # "Actual" or "Forecasted"
    operator       = string                     # "EqualTo", "GreaterThan", "GreaterThanOrEqualTo"
    contact_emails = optional(list(string), [])
  }))
  default = [
    {
      enabled        = true
      threshold      = 50.0
      threshold_type = "Actual"
      operator       = "EqualTo"
      contact_emails = []
    },
    {
      enabled        = true
      threshold      = 80.0
      threshold_type = "Actual"
      operator       = "EqualTo"
      contact_emails = []
    },
    {
      enabled        = true
      threshold      = 100.0
      threshold_type = "Forecasted"
      operator       = "GreaterThan"
      contact_emails = []
    }
  ]
}

variable "filter_tags" {
  description = "Map of tags to filter budget by. Only resources with these tags will be included in the budget."
  type        = map(list(string))
  default     = null
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod) for tagging and resource naming."
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
