# ============================================================================
# Azure Virtual Network Manager Module - Main Configuration
# ============================================================================
# This module creates a complete Azure Virtual Network Manager infrastructure:
# - Network Manager Instance with scope definition (Management Group or Subscription)
# - Network Groups (static or dynamic via Azure Policy)
# - Connectivity Configuration (hub-and-spoke or mesh)
# - Security Admin Rules (organization-level security policies)
# - Routing Configuration with routing rules (next-hop, etc.)
# - Configuration Deployment to regions
#
# Architecture:
# Network Manager Instance
#   ├── Network Groups
#   │   ├── Static Membership VNets
#   │   └── Dynamic Membership (via Azure Policy)
#   ├── Connectivity Configuration
#   │   ├── Hub-and-Spoke Topology
#   │   └── Mesh Topology
#   ├── Security Admin Rules
#   └── Routing Configuration
#       └── Routing Rules (next-hop, etc.)
# ============================================================================

# ----------------------------------------------------------------------------
# Local Values
# ----------------------------------------------------------------------------
# Abbreviation used for resource naming conventions
# ----------------------------------------------------------------------------
locals {
  abbreviation = "vnm"
}

# ----------------------------------------------------------------------------
# Resource Group (Optional)
# ----------------------------------------------------------------------------
# Creates a resource group if one is not provided.
# This allows the module to be self-contained or use an existing resource group.
#
# If resource_group_name is empty, a new resource group will be created
# using the resource-group module with standardized naming conventions.
# ----------------------------------------------------------------------------
module "resource_group" {
  # Use repository URL for module source
  # Repository: git@github.com:smyha/TerraformTutorial.git
  # Path: terraform-up-and-running-code/code/terraform/TUTORIAL/azure-networking-tutorial/modules/resource-group
  source = "git::git@github.com:smyha/TerraformTutorial.git//terraform-up-and-running-code/code/terraform/TUTORIAL/azure-networking-tutorial/modules/resource-group"
  count  = var.resource_group_name == "" ? 1 : 0

  project_name     = var.project_name != "" ? var.project_name : "network-manager"
  application_name = var.application_name != "" ? var.application_name : local.abbreviation
  environment      = var.environment != "" ? var.environment : "rg"
  location         = var.location
  tags             = var.tags
}

# ----------------------------------------------------------------------------
# Network Manager Instance
# ----------------------------------------------------------------------------
# The Network Manager instance is the top-level resource that defines the
# scope of management. It provides centralized governance across multiple
# subscriptions and regions.
#
# Scope can be defined at:
# - Management Group level: For enterprise-wide governance
# - Subscription level: For subscription-specific management
#
# Scope Access defines what operations the Network Manager can perform:
# - Connectivity: Manage VNet peering and connectivity topologies
# - SecurityAdmin: Manage security admin rules (override NSG rules)
# - Routing: Manage routing configurations and user-defined routes
# ----------------------------------------------------------------------------
resource "azurerm_network_manager" "main" {
  name                = var.network_manager_name
  location            = try(module.resource_group[0].resource_group_location, var.location)
  resource_group_name = try(module.resource_group[0].resource_group_name, var.resource_group_name)

  # Scope defines what the Network Manager can manage
  # Can be defined at Management Group or Subscription level
  # Management Group scope is useful for enterprise-wide governance
  # Subscription scope is useful for subscription-specific management
  #
  # IMPORTANT: At least one of scope_management_group_ids or scope_subscription_ids must be provided
  scope {
    # Management Group IDs (optional) - for enterprise-wide governance
    # When using Management Group scope, the Network Manager can manage
    # all subscriptions under the specified Management Groups
    management_group_ids = var.scope_management_group_ids != null ? var.scope_management_group_ids : []

    # Subscription IDs (optional) - for subscription-specific management
    # When using Subscription scope, the Network Manager can manage
    # only the specified subscriptions
    subscription_ids = var.scope_subscription_ids != null ? var.scope_subscription_ids : []
  }

  # Validate that at least one scope is provided
  lifecycle {
    precondition {
      condition     = (var.scope_management_group_ids != null && length(var.scope_management_group_ids) > 0) || (var.scope_subscription_ids != null && length(var.scope_subscription_ids) > 0)
      error_message = "At least one of scope_management_group_ids or scope_subscription_ids must be provided and non-empty."
    }
  }

  # Scope access defines what operations the Network Manager can perform
  # Valid values: "Connectivity", "SecurityAdmin", "Routing"
  # - Connectivity: Allows managing VNet peering and connectivity topologies
  # - SecurityAdmin: Allows managing security admin rules (evaluated before NSG rules)
  # - Routing: Allows managing routing configurations and user-defined routes
  scope_accesses = var.scope_accesses

  description = var.description

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Network Groups
# ----------------------------------------------------------------------------
# Network Groups serve as logical containers of networking resources (VNets).
# They allow you to group VNets together for applying configurations.
#
# Membership types:
# - Static: VNets are explicitly added to the group (via static_member_vnet_ids)
# - Dynamic: VNets are automatically added based on Azure Policy conditions
#
# Use cases:
# - Group VNets by environment (production, staging, development)
# - Group VNets by workload (web, database, application)
# - Group VNets by team or department
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_network_group" "main" {
  for_each = var.network_groups

  name               = each.key
  network_manager_id = azurerm_network_manager.main.id
  description        = each.value.description
}

# ----------------------------------------------------------------------------
# Network Group Static Members
# ----------------------------------------------------------------------------
# Add virtual networks to network groups statically.
# Static membership means you explicitly define which VNets belong to a group.
#
# Note: Dynamic membership via Azure Policy is configured separately in Azure Policy.
# When using dynamic membership, VNets are automatically added to groups based on
# policy conditions (e.g., tags, resource location, etc.)
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_static_member" "main" {
  for_each = {
    for pair in flatten([
      for ng_key, ng_value in var.network_groups : [
        for vnet_id in ng_value.static_member_vnet_ids != null ? ng_value.static_member_vnet_ids : [] : {
          key  = "${ng_key}-${replace(replace(vnet_id, "/", "-"), ":", "-")}"
          ng   = ng_key
          vnet = vnet_id
        }
      ]
    ]) : pair.key => pair
  }

  name                      = "static-member-${substr(each.value.key, 0, min(length(each.value.key), 80))}"
  network_group_id          = azurerm_network_manager_network_group.main[each.value.ng].id
  target_virtual_network_id = each.value.vnet

  depends_on = [
    azurerm_network_manager_network_group.main
  ]
}

# ----------------------------------------------------------------------------
# Connectivity Configuration
# ----------------------------------------------------------------------------
# Connectivity configurations define how VNets connect to each other.
# This is the core feature that enables centralized VNet peering management.
#
# Topology types:
# - HubAndSpoke: All spoke VNets connect to a central hub VNet
#   - Use case: Centralized security, shared services, cost optimization
#   - Hub VNet typically contains shared services (firewall, DNS, etc.)
#   - Spoke VNets contain application workloads
# - Mesh: All VNets connect directly to each other (full mesh)
#   - Use case: High-performance inter-VNet communication
#   - All VNets can communicate directly without going through a hub
#
# Group Connectivity:
# - "DirectlyConnected": VNets in the group can communicate directly
# - "None": VNets in the group cannot communicate (only connect to hub in hub-and-spoke)
#
# Important: The hub VNet must exist before creating the connectivity configuration.
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_connectivity_configuration" "main" {
  for_each = var.connectivity_configurations

  name               = each.key
  network_manager_id = azurerm_network_manager.main.id

  # Topology type: "HubAndSpoke" or "Mesh"
  connectivity_topology = each.value.topology

  # Apply to network groups
  # All VNets in these network groups will have connectivity configured
  dynamic "applies_to_group" {
    for_each = each.value.network_group_names
    content {
      network_group_id = azurerm_network_manager_network_group.main[applies_to_group.value].id

      # Group connectivity: "None" or "DirectlyConnected"
      # - "None": VNets in the group don't connect to each other (only to hub in hub-and-spoke)
      # - "DirectlyConnected": VNets in the group can communicate directly
      group_connectivity = each.value.group_connectivity != null ? each.value.group_connectivity : "None"

      # Use hub gateway: If true, spokes can use hub's VPN/ExpressRoute gateway
      # This enables hub-based connectivity to on-premises networks
      use_hub_gateway = each.value.use_hub_gateway != null ? each.value.use_hub_gateway : false
    }
  }

  # Hub configuration (required for hub-and-spoke topology)
  # The hub VNet is the central VNet that all spoke VNets connect to
  dynamic "hub" {
    for_each = each.value.topology == "HubAndSpoke" && each.value.hub != null ? [each.value.hub] : []
    content {
      resource_id   = hub.value.resource_id   # Full resource ID of the hub VNet
      resource_type = hub.value.resource_type # "Microsoft.Network/virtualNetworks"
    }
  }

  # Delete existing peerings before applying new configuration
  # WARNING: This will delete existing VNet peerings that conflict with the configuration
  # Set to false if you want to preserve existing peerings
  delete_existing_peering_enabled = each.value.delete_existing_peering_enabled

  description = each.value.description

  depends_on = [
    azurerm_network_manager.main,
    azurerm_network_manager_network_group.main
  ]
}

# ----------------------------------------------------------------------------
# Security Admin Configuration
# ----------------------------------------------------------------------------
# Security Admin Rules provide organization-level security policies that
# override NSG (Network Security Group) rules. They are evaluated BEFORE NSG rules.
#
# Rule evaluation order:
# 1. Security Admin Rules (highest priority - organization-level)
# 2. NSG Rules (resource-level)
# 3. Default Azure rules (lowest priority)
#
# Use cases:
# - Enforce organization-wide security policies (e.g., block all internet inbound)
# - Override per-resource NSG rules for compliance
# - Centralize security governance across multiple subscriptions
#
# Important: Security Admin Rules have the highest priority and cannot be
# overridden by NSG rules. Use with caution in production environments.
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_security_admin_configuration" "main" {
  for_each = var.security_admin_configurations

  name               = each.key
  network_manager_id = azurerm_network_manager.main.id
  description        = each.value.description

  # Apply to network groups
  # All VNets in these network groups will have security admin rules applied
  dynamic "applies_to_group" {
    for_each = each.value.network_group_names
    content {
      network_group_id = azurerm_network_manager_network_group.main[applies_to_group.value].id
    }
  }

  depends_on = [
    azurerm_network_manager_network_group.main
  ]
}

# ----------------------------------------------------------------------------
# Security Admin Rule Collections
# ----------------------------------------------------------------------------
# Rule collections group related security admin rules together.
# This allows you to organize rules logically (e.g., all internet blocking rules,
# all internal traffic rules, etc.)
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_admin_rule_collection" "main" {
  for_each = var.security_admin_rule_collections

  name                            = each.key
  security_admin_configuration_id = azurerm_network_manager_security_admin_configuration.main[each.value.security_admin_configuration_name].id

  # Network groups that this rule collection applies to
  network_group_ids = [
    for ng_name in each.value.network_group_names :
    azurerm_network_manager_network_group.main[ng_name].id
  ]

  description = each.value.description

  depends_on = [
    azurerm_network_manager_security_admin_configuration.main
  ]
}

# ----------------------------------------------------------------------------
# Security Admin Rules
# ----------------------------------------------------------------------------
# Define security admin rules that are evaluated before NSG rules.
# These rules have the highest priority in the rule evaluation order.
#
# Rule properties:
# - Priority: Lower number = higher priority (e.g., 100 is evaluated before 200)
# - Direction: "Inbound" or "Outbound"
# - Action: "Allow" or "Deny"
# - Protocol: "Tcp", "Udp", "Icmp", "Esp", "Any", "Ah"
# - Source/Destination: Can be IP prefix, Service Tag, or Default
#
# Common use cases:
# - Deny all inbound internet traffic (0.0.0.0/0 from Internet)
# - Allow specific service tags (e.g., AzureKeyVault, Storage)
# - Block specific IP ranges or countries
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_admin_rule" "main" {
  for_each = var.security_admin_rules

  name                     = each.key
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.main[each.value.rule_collection_name].id

  # Priority: Lower number = higher priority
  # Rules are evaluated in priority order, first matching rule wins
  priority = each.value.priority

  # Direction: "Inbound" or "Outbound"
  direction = each.value.direction

  # Action: "Allow" or "Deny"
  action = each.value.action

  # Protocol: "Tcp", "Udp", "Icmp", "Esp", "Any", "Ah"
  protocol = each.value.protocol

  # Source configuration
  # Defines where the traffic originates from
  source {
    # Address prefix type: "IPPrefix", "ServiceTag", or "Default"
    address_prefix_type = each.value.source_address_prefix_type

    # Address prefix: Required for IPPrefix and ServiceTag, null for Default
    # Examples:
    # - IPPrefix: "10.0.0.0/8", "192.168.1.0/24"
    # - ServiceTag: "Internet", "VirtualNetwork", "AzureKeyVault", "Storage"
    address_prefix = each.value.source_address_prefix_type == "IPPrefix" || each.value.source_address_prefix_type == "ServiceTag" ? each.value.source_address_prefix : null
  }

  # Destination configuration
  # Defines where the traffic is going to
  destination {
    address_prefix_type = each.value.destination_address_prefix_type
    address_prefix      = each.value.destination_address_prefix_type == "IPPrefix" || each.value.destination_address_prefix_type == "ServiceTag" ? each.value.destination_address_prefix : null
  }

  # Port ranges
  # Source ports: Which ports the traffic originates from
  source_port_ranges = each.value.source_port_ranges

  # Destination ports: Which ports the traffic is going to
  destination_port_ranges = each.value.destination_port_ranges

  description = each.value.description

  depends_on = [
    azurerm_network_manager_admin_rule_collection.main
  ]
}

# ----------------------------------------------------------------------------
# Routing Configuration
# ----------------------------------------------------------------------------
# Routing configurations let you orchestrate user-defined routes at scale
# to control traffic flow according to your desired routing behavior.
#
# Use cases:
# - Force traffic through a firewall (next-hop to Virtual Appliance)
# - Route specific traffic through a VPN gateway
# - Implement custom routing policies across multiple VNets
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_routing_configuration" "main" {
  for_each = var.routing_configurations

  name               = each.key
  network_manager_id = azurerm_network_manager.main.id

  # Apply to network groups
  # All VNets in these network groups will have the routing rules applied
  dynamic "applies_to_group" {
    for_each = each.value.network_group_names
    content {
      network_group_id = azurerm_network_manager_network_group.main[applies_to_group.value].id
    }
  }

  description = each.value.description

  depends_on = [
    azurerm_network_manager_network_group.main
  ]
}

# ----------------------------------------------------------------------------
# Routing Rule Collections
# ----------------------------------------------------------------------------
# Routing rule collections group related routing rules together.
# This allows you to organize rules logically (e.g., all firewall rules,
# all VPN rules, etc.)
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_routing_rule_collection" "main" {
  for_each = var.routing_rule_collections

  name                     = each.key
  routing_configuration_id = azurerm_network_manager_routing_configuration.main[each.value.routing_configuration_name].id

  # Network groups that this rule collection applies to
  network_group_ids = [
    for ng_name in each.value.network_group_names :
    azurerm_network_manager_network_group.main[ng_name].id
  ]

  description = each.value.description

  depends_on = [
    azurerm_network_manager_routing_configuration.main,
    azurerm_network_manager_network_group.main
  ]
}

# ----------------------------------------------------------------------------
# Routing Rules
# ----------------------------------------------------------------------------
# Routing rules define how traffic should be routed.
# Common use cases:
# - Next-hop to firewall: Route all internet traffic (0.0.0.0/0) through Azure Firewall
# - Next-hop to VPN: Route specific prefixes through VPN gateway
# - Next-hop to Internet: Route traffic directly to internet
#
# Rule evaluation:
# - Rules are evaluated in the order they are defined in the rule collection
# - First matching rule is applied
# - If no rule matches, default Azure routing is used
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_routing_rule" "main" {
  for_each = var.routing_rules

  name               = each.key
  rule_collection_id = azurerm_network_manager_routing_rule_collection.main[each.value.rule_collection_name].id
  description        = each.value.description

  # Destination configuration
  # Defines which traffic this rule applies to
  destination {
    # Explanation of the destination type and address: "AddressPrefix" or "ServiceTag"
    # "AddressPrefix" means a specific IP range (e.g., "10.0.0.0/8")
    # "ServiceTag" means a predefined Azure service (e.g., "Internet", "VirtualNetwork", "AzureKeyVault", "Storage")
    type = each.value.destination_type # "AddressPrefix" or "ServiceTag"

    # Address: The IP range or Azure service tag to match (e.g., "0.0.0.0/0" or "Internet")
    address = each.value.destination_address # e.g., "0.0.0.0/0" or "Internet" or "AzureKeyVault" or "Storage"
  }

  # Next-hop configuration  : "VirtualAppliance", "Internet", "VnetLocal", "VnetPeering", "None", "VirtualNetworkGateway", "ExpressRouteGateway"
  # Defines where traffic matching this rule should be sent
  next_hop {
    type = each.value.next_hop_type # "VirtualAppliance", "Internet", "VnetLocal", "VnetPeering", "None", "VirtualNetworkGateway", "ExpressRouteGateway"
    # Address: The IP address or Azure service tag to send the traffic to (e.g., "10.0.1.4" or "Internet")
    address = each.value.next_hop_address # IP address for VirtualAppliance, null for others
  }

  depends_on = [
    azurerm_network_manager_routing_rule_collection.main
  ]
}

# ----------------------------------------------------------------------------
# Configuration Deployment
# ----------------------------------------------------------------------------
# Configurations do not take effect until they are deployed to regions
# containing your target network resources.
#
# IMPORTANT: After creating configurations, you MUST deploy them to regions
# where your VNets are located. Configurations are not applied automatically.
#
# Deployment process:
# 1. Create configurations (connectivity, security, routing)
# 2. Deploy configurations to regions (this resource)
# 3. Configurations are applied to VNets in those regions
#
# Scope Access types:
# - "Connectivity": Deploy connectivity configurations (VNet peering: "None" or "DirectlyConnected")
# - "SecurityAdmin": Deploy security admin configurations (security rules: "Allow" or "Deny")
# - "Routing": Deploy routing configurations (user-defined routes: "VirtualAppliance", "Internet", "VnetLocal", "VnetPeering", "None", "VirtualNetworkGateway", "ExpressRouteGateway")
#
# Best practice: Deploy to non-production regions first, then production.
# ----------------------------------------------------------------------------
resource "azurerm_network_manager_deployment" "main" {
  for_each = var.deployments

  location           = each.value.location
  network_manager_id = azurerm_network_manager.main.id

  # Scope access: "Connectivity", "SecurityAdmin", or "Routing"
  # Must match the type of configurations being deployed
  scope_access = each.value.scope_access

  # Configuration IDs to deploy
  # These are the IDs of the configurations created above
  # You can deploy multiple configurations of the same type to a region
  configuration_ids = each.value.configuration_ids

  # Triggers to force redeployment when configurations change
  # This ensures deployments are updated when underlying configurations change
  triggers = {
    # Force redeployment when connectivity configurations change
    connectivity_configs = join(",", [for k, v in azurerm_network_manager_connectivity_configuration.main : "${k}-${v.id}"])

    # Force redeployment when security admin configurations change
    security_configs = join(",", [for k, v in azurerm_network_manager_security_admin_configuration.main : "${k}-${v.id}"])

    # Force redeployment when routing configurations change
    routing_configs = join(",", [for k, v in azurerm_network_manager_routing_configuration.main : "${k}-${v.id}"])
  }

  depends_on = [
    azurerm_network_manager_connectivity_configuration.main,
    azurerm_network_manager_security_admin_configuration.main,
    azurerm_network_manager_routing_configuration.main
  ]
}

