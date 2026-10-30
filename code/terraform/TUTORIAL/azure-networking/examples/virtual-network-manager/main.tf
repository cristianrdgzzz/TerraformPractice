# ============================================================================
# Azure Virtual Network Manager Example
# ============================================================================
# This example demonstrates how to use the Virtual Network Manager module
# to create a complete network governance solution with:
# - Network Manager with Management Group or Subscription scope
# - Network Groups for organizing VNets
# - Hub-and-Spoke connectivity configuration
# - Security Admin Rules for organization-level security
# - Routing Rules to force traffic through Azure Firewall
# - Configuration deployments to regions
#
# Architecture:
# - Network Manager Instance (Management Group or Subscription scope)
# - Network Groups (Production, Development, Shared Services)
# - Hub-and-Spoke Connectivity (with hub gateway support)
# - Security Admin Rules (deny internet inbound, allow internal)
# - Routing Rules (next-hop to Azure Firewall)
# ============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# ----------------------------------------------------------------------------
# Provider Configuration
# ----------------------------------------------------------------------------
provider "azurerm" {
  features {}
}

# ----------------------------------------------------------------------------
# Resource Group Module
# ----------------------------------------------------------------------------
# Create resource group using the resource-group module if not provided
module "resource_group" {
  # Use repository URL for module source
  # Repository: git@github.com:smyha/TerraformTutorial.git
  # Path: terraform-up-and-running-code/code/terraform/TUTORIAL/azure-networking-tutorial/modules/resource-group
  source = "git::git@github.com:smyha/TerraformTutorial.git//terraform-up-and-running-code/code/terraform/TUTORIAL/azure-networking-tutorial/modules/resource-group"
  count  = var.resource_group_name == "" ? 1 : 0

  project_name     = var.project_name != "" ? var.project_name : "network-manager"
  application_name = var.application_name != "" ? var.application_name : "vnm"
  environment      = var.environment != "" ? var.environment : "example"
  location         = var.location
  tags             = var.tags
}

# ----------------------------------------------------------------------------
# Virtual Network Manager Module
# ----------------------------------------------------------------------------
module "network_manager" {
  # Use repository URL for module source
  # Repository: git@github.com:smyha/TerraformTutorial.git
  # Path: terraform-up-and-running-code/code/terraform/TUTORIAL/azure-networking-tutorial/modules/virtual-network-manager
  source = "git::git@github.com:smyha/TerraformTutorial.git//terraform-up-and-running-code/code/terraform/TUTORIAL/azure-networking-tutorial/modules/virtual-network-manager"

  # Resource Group
  resource_group_name  = var.resource_group_name != "" ? var.resource_group_name : try(module.resource_group[0].resource_group_name, "")
  location             = var.location
  network_manager_name = var.network_manager_name

  # Resource Group Auto-creation (if resource_group_name is empty)
  project_name     = var.project_name
  application_name = var.application_name
  environment      = var.environment

  # Scope Configuration
  scope_management_group_ids = var.scope_management_group_ids
  scope_subscription_ids     = var.scope_subscription_ids
  scope_accesses             = var.scope_accesses

  description = var.network_manager_description

  # Network Groups
  network_groups = var.network_groups

  # Connectivity Configurations
  connectivity_configurations = var.connectivity_configurations

  # Security Admin Configurations
  security_admin_configurations = var.security_admin_configurations

  # Security Admin Rule Collections
  security_admin_rule_collections = var.security_admin_rule_collections

  # Security Admin Rules
  security_admin_rules = var.security_admin_rules

  # Routing Configurations
  routing_configurations = var.routing_configurations

  # Routing Rule Collections
  routing_rule_collections = var.routing_rule_collections

  # Routing Rules
  routing_rules = var.routing_rules

  # Deployments
  # Note: Configuration IDs are resolved from module outputs
  # For initial deployment, you may need to run terraform apply twice:
  # 1. First apply creates configurations
  # 2. Second apply deploys configurations with IDs from first apply
  deployments = var.deployments

  tags = var.tags
}

