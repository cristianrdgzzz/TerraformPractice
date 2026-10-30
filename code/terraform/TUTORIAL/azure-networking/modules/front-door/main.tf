# ============================================================================
# Azure Front Door Module - Main Configuration
# ============================================================================
# Azure Front Door is a global, scalable entry point that provides:
# - Global load balancing
# - WAF protection
# - SSL/TLS termination
# - Edge caching
# - URL rewrite
#
# Architecture:
# Global Users
#     ↓
# Azure Front Door (Global Network)
#     ├── Edge Location 1 (US East)
#     ├── Edge Location 2 (Europe)
#     └── Edge Location 3 (Asia)
#     ↓
# Origin Servers (Azure/On-Premises)
# ============================================================================

# ----------------------------------------------------------------------------
# Front Door (Classic)
# ----------------------------------------------------------------------------
# Azure Front Door (classic) is a global, scalable entry point that provides:
# - Global load balancing across Azure regions
# - WAF protection
# - SSL/TLS termination
# - Edge caching
# - URL rewrite and redirect
#
# Note: Front Door is a global service and does not require a location attribute.
# The location variable is kept for consistency but not used in the resource.
#
# Important: Azure Front Door Standard/Premium uses different resources
# (azurerm_cdn_frontdoor_profile, azurerm_cdn_frontdoor_endpoint, etc.)
# This module uses the classic Front Door resource (azurerm_frontdoor) for compatibility.
# ----------------------------------------------------------------------------
resource "azurerm_frontdoor" "main" {
  name                  = var.front_door_name
  resource_group_name   = var.resource_group_name
  friendly_name         = var.friendly_name != null ? var.friendly_name : var.front_door_name
  load_balancer_enabled = var.load_balancer_enabled

  # Backend Pools
  dynamic "backend_pool" {
    for_each = var.backend_pools
    content {
      name                = backend_pool.value.name
      health_probe_name   = backend_pool.value.health_probe_name
      load_balancing_name = backend_pool.value.load_balancing_name

      dynamic "backend" {
        for_each = backend_pool.value.backends
        content {
          host_header = backend.value.host_header
          address     = backend.value.address
          http_port   = backend.value.http_port
          https_port  = backend.value.https_port
          priority    = backend.value.priority
          weight      = backend.value.weight
          enabled     = backend.value.enabled
        }
      }
    }
  }

  # Backend Pool Health Probes
  dynamic "backend_pool_health_probe" {
    for_each = var.backend_pool_health_probes
    content {
      name                = backend_pool_health_probe.value.name
      protocol            = backend_pool_health_probe.value.protocol
      path                = backend_pool_health_probe.value.path
      interval_in_seconds = backend_pool_health_probe.value.interval_in_seconds
      enabled             = backend_pool_health_probe.value.enabled
    }
  }

  # Backend Pool Load Balancing Settings
  dynamic "backend_pool_load_balancing" {
    for_each = var.backend_pool_load_balancing
    content {
      name                            = backend_pool_load_balancing.value.name
      sample_size                     = backend_pool_load_balancing.value.sample_size
      successful_samples_required     = backend_pool_load_balancing.value.successful_samples_required
      additional_latency_milliseconds = backend_pool_load_balancing.value.additional_latency_milliseconds
    }
  }

  # Frontend Endpoints
  dynamic "frontend_endpoint" {
    for_each = var.frontend_endpoints
    content {
      name                                    = frontend_endpoint.value.name
      host_name                               = frontend_endpoint.value.host_name
      session_affinity_enabled                = frontend_endpoint.value.session_affinity_enabled
      session_affinity_ttl_seconds            = frontend_endpoint.value.session_affinity_ttl_seconds
      web_application_firewall_policy_link_id = frontend_endpoint.value.web_application_firewall_policy_link_id
    }
  }

  # Routing Rules
  dynamic "routing_rule" {
    for_each = var.routing_rules
    content {
      name               = routing_rule.value.name
      frontend_endpoints = routing_rule.value.frontend_endpoints
      accepted_protocols = routing_rule.value.accepted_protocols
      patterns_to_match  = routing_rule.value.patterns_to_match
      enabled            = routing_rule.value.enabled

      # Forwarding Configuration
      dynamic "forwarding_configuration" {
        for_each = routing_rule.value.route_configuration != null && routing_rule.value.route_configuration.forwarding_protocol != null ? [routing_rule.value.route_configuration] : []
        content {
          forwarding_protocol                   = forwarding_configuration.value.forwarding_protocol
          backend_pool_name                     = forwarding_configuration.value.backend_pool_name
          cache_enabled                         = forwarding_configuration.value.cache_enabled != null ? forwarding_configuration.value.cache_enabled : false
          cache_query_parameter_strip_directive = forwarding_configuration.value.cache_query_parameter_strip_directive != null ? forwarding_configuration.value.cache_query_parameter_strip_directive : "StripNone"
          cache_duration                        = forwarding_configuration.value.cache_duration
          cache_use_dynamic_compression         = forwarding_configuration.value.compression_enabled != null ? forwarding_configuration.value.compression_enabled : false
          custom_forwarding_path                = forwarding_configuration.value.forwarding_path
        }
      }

      # Redirect Configuration
      dynamic "redirect_configuration" {
        for_each = routing_rule.value.route_configuration != null && routing_rule.value.route_configuration.redirect_type != null ? [routing_rule.value.route_configuration] : []
        content {
          redirect_type       = redirect_configuration.value.redirect_type
          redirect_protocol   = redirect_configuration.value.redirect_protocol
          custom_host         = redirect_configuration.value.redirect_host
          custom_path         = redirect_configuration.value.redirect_path
          custom_query_string = redirect_configuration.value.redirect_query_string
          custom_fragment     = redirect_configuration.value.redirect_fragment
        }
      }
    }
  }

  tags = var.tags
}

