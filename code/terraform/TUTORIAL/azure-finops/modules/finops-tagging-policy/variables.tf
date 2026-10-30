# ============================================================================
# Azure FinOps Tagging Policy Module - Variables
# ============================================================================

variable "subscription_id" {
  description = "The ID of the Azure Subscription to apply the policy to (required if assignment_scope is 'subscription'). Format: /subscriptions/{subscription-id}"
  type        = string
  default     = null
}

variable "management_group_id" {
  description = "The ID of the Management Group to apply the policy to (required if assignment_scope is 'management_group'). Format: /providers/Microsoft.Management/managementGroups/{management-group-id}"
  type        = string
  default     = null
}

variable "resource_group_id" {
  description = "The ID of the Resource Group to apply the policy to (required if assignment_scope is 'resource_group'). Format: /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}"
  type        = string
  default     = null
}

variable "assignment_scope" {
  description = "Scope of the policy assignment. Options: 'subscription', 'management_group', 'resource_group'."
  type        = string
  default     = "subscription"
  validation {
    condition     = contains(["subscription", "management_group", "resource_group"], var.assignment_scope)
    error_message = "Assignment scope must be 'subscription', 'management_group', or 'resource_group'."
  }
}

variable "required_tags" {
  description = "List of required tags with their configuration."
  type = list(object({
    name           = string
    display_name   = optional(string)
    description    = optional(string)
    default_value  = optional(string)       # Used with Modify effect
    allowed_values = optional(list(string)) # Optional validation
  }))
  default = [
    {
      name         = "CostCenter"
      display_name = "Cost Center"
      description  = "Cost center or budget code for cost allocation"
    },
    {
      name         = "Owner"
      display_name = "Owner"
      description  = "Team or individual responsible for this resource"
    },
    {
      name           = "Environment"
      display_name   = "Environment"
      description    = "Environment name (dev, staging, prod)"
      allowed_values = ["dev", "staging", "prod"]
    }
  ]
}

variable "policy_name" {
  description = "Name of the policy definition."
  type        = string
  default     = "finops-required-tags"
}

variable "policy_display_name" {
  description = "Display name of the policy definition."
  type        = string
  default     = "FinOps: Require mandatory tags"
}

variable "policy_description" {
  description = "Description of the policy definition."
  type        = string
  default     = "Enforces mandatory tags on resources for FinOps cost allocation and governance."
}

variable "policy_category" {
  description = "Category of the policy definition."
  type        = string
  default     = "FinOps"
}

variable "policy_mode" {
  description = "Mode of the policy definition. Options: 'Indexed', 'All', 'Microsoft.KeyVault.Data'."
  type        = string
  default     = "Indexed"
  validation {
    condition     = contains(["Indexed", "All", "Microsoft.KeyVault.Data"], var.policy_mode)
    error_message = "Policy mode must be 'Indexed', 'All', or 'Microsoft.KeyVault.Data'."
  }
}

variable "policy_effect" {
  description = "The effect of the policy. Options: 'Audit', 'Deny', 'Modify', 'Disabled'."
  type        = string
  default     = "Audit"
  validation {
    condition     = contains(["Audit", "Deny", "Modify", "Disabled"], var.policy_effect)
    error_message = "Policy effect must be 'Audit', 'Deny', 'Modify', or 'Disabled'."
  }
}

variable "assignment_name" {
  description = "Name of the policy assignment. If null, auto-generated."
  type        = string
  default     = null
}

variable "assignment_display_name" {
  description = "Display name of the policy assignment. If null, uses default."
  type        = string
  default     = null
}

variable "assignment_description" {
  description = "Description of the policy assignment."
  type        = string
  default     = "Enforces mandatory tags for FinOps cost allocation."
}

variable "assignment_location" {
  description = "Location for the policy assignment (required for Modify effect)."
  type        = string
  default     = "eastus"
}

variable "non_compliance_message" {
  description = "Custom message shown when resources are non-compliant."
  type        = string
  default     = null
}

variable "enforcement_mode" {
  description = "Whether the policy is enforced. Options: 'Default' (enforced) or 'DoNotEnforce' (evaluation only)."
  type        = string
  default     = "Default"
  validation {
    condition     = contains(["Default", "DoNotEnforce"], var.enforcement_mode)
    error_message = "Enforcement mode must be 'Default' or 'DoNotEnforce'."
  }
}

variable "resource_selectors" {
  description = "Optional resource selectors to filter which resources the policy applies to."
  type = object({
    name   = string
    kind   = string
    in     = optional(list(string))
    not_in = optional(list(string))
  })
  default = null
}

variable "tags" {
  description = "Map of tags to apply to policy resources."
  type        = map(string)
  default     = {}
}
