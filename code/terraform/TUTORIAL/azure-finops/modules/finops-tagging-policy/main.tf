# ============================================================================
# Azure FinOps Tagging Policy Module - Main Configuration
# ============================================================================
# This module creates Azure Policy definitions and assignments to enforce
# mandatory tags on resources for cost allocation and governance.
#
# Key Features:
# - Enforce multiple mandatory tags (CostCenter, Owner, Environment, etc.)
# - Flexible policy effects (Audit, Deny, Modify)
# - Support for subscription, management group, or resource group scope
# - Optional tag value validation
# ============================================================================

# ----------------------------------------------------------------------------
# Policy Definition: Required Tags
# ----------------------------------------------------------------------------
resource "azurerm_policy_definition" "tagging" {
  name         = var.policy_name
  policy_type  = "Custom"
  mode         = var.policy_mode
  display_name = var.policy_display_name
  description  = var.policy_description

  metadata = jsonencode({
    category = var.policy_category
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        for tag in var.required_tags : {
          field  = "tags['${tag.name}']"
          exists = "false"
        }
      ]
    }
    then = {
      effect = var.policy_effect
      details = var.policy_effect == "Modify" ? {
        type      = "Microsoft.Resources/tags"
        operation = "addOrReplace"
        value = {
          for tag in var.required_tags : tag.name => tag.default_value
          if tag.default_value != null
        }
      } : null
    }
  })

  parameters = jsonencode({
    for tag in var.required_tags : tag.name => {
      type = "String"
      metadata = {
        displayName = tag.display_name != null ? tag.display_name : tag.name
        description = tag.description != null ? tag.description : "Required tag: ${tag.name}"
      }
      allowedValues = tag.allowed_values != null ? tag.allowed_values : null
    }
  })
}

# ----------------------------------------------------------------------------
# Policy Assignment: Subscription Scope
# ----------------------------------------------------------------------------
resource "azurerm_subscription_policy_assignment" "tagging" {
  count = var.assignment_scope == "subscription" ? 1 : 0

  name                 = var.assignment_name != null ? var.assignment_name : "finops-tagging-assignment"
  policy_definition_id = azurerm_policy_definition.tagging.id
  subscription_id      = var.subscription_id
  location             = var.assignment_location
  display_name         = var.assignment_display_name != null ? var.assignment_display_name : "FinOps: Required Tags"
  description          = var.assignment_description

  # Non-compliance message
  non_compliance_message {
    content = var.non_compliance_message != null ? var.non_compliance_message : "Resources must have the following required tags: ${join(", ", [for tag in var.required_tags : tag.name])}"
  }

  # Identity for remediation (if using Modify effect)
  identity {
    type = var.policy_effect == "Modify" ? "SystemAssigned" : "None"
  }

  # Enforcement mode
  enforcement_mode = var.enforcement_mode

  # Resource selectors (optional - filter which resources the policy applies to)
  dynamic "resource_selectors" {
    for_each = var.resource_selectors != null ? [var.resource_selectors] : []
    content {
      name = resource_selectors.value.name
      selectors {
        kind   = resource_selectors.value.kind
        in     = resource_selectors.value.in
        not_in = resource_selectors.value.not_in
      }
    }
  }

  metadata = jsonencode({
    category = "FinOps"
    version  = "1.0.0"
  })
}

# ----------------------------------------------------------------------------
# Policy Assignment: Management Group Scope
# ----------------------------------------------------------------------------
resource "azurerm_management_group_policy_assignment" "tagging" {
  count = var.assignment_scope == "management_group" ? 1 : 0

  name                 = var.assignment_name != null ? var.assignment_name : "finops-tagging-assignment"
  policy_definition_id = azurerm_policy_definition.tagging.id
  management_group_id  = var.management_group_id
  location             = var.assignment_location
  display_name         = var.assignment_display_name != null ? var.assignment_display_name : "FinOps: Required Tags"
  description          = var.assignment_description

  non_compliance_message {
    content = var.non_compliance_message != null ? var.non_compliance_message : "Resources must have the following required tags: ${join(", ", [for tag in var.required_tags : tag.name])}"
  }

  identity {
    type = var.policy_effect == "Modify" ? "SystemAssigned" : "None"
  }

  enforcement_mode = var.enforcement_mode

  metadata = jsonencode({
    category = "FinOps"
    version  = "1.0.0"
  })
}

# ----------------------------------------------------------------------------
# Policy Assignment: Resource Group Scope
# ----------------------------------------------------------------------------
resource "azurerm_resource_group_policy_assignment" "tagging" {
  count = var.assignment_scope == "resource_group" ? 1 : 0

  name                 = var.assignment_name != null ? var.assignment_name : "finops-tagging-assignment"
  policy_definition_id = azurerm_policy_definition.tagging.id
  resource_group_id    = var.resource_group_id
  location             = var.assignment_location
  display_name         = var.assignment_display_name != null ? var.assignment_display_name : "FinOps: Required Tags"
  description          = var.assignment_description

  non_compliance_message {
    content = var.non_compliance_message != null ? var.non_compliance_message : "Resources must have the following required tags: ${join(", ", [for tag in var.required_tags : tag.name])}"
  }

  identity {
    type = var.policy_effect == "Modify" ? "SystemAssigned" : "None"
  }

  enforcement_mode = var.enforcement_mode

  metadata = jsonencode({
    category = "FinOps"
    version  = "1.0.0"
  })
}
