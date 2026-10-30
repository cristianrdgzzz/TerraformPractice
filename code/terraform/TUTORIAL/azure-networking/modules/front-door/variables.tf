# ============================================================================
# Azure Front Door Module - Variables
# ============================================================================
# Azure Front Door is a global, scalable entry point that uses the Microsoft
# global network to deliver your applications.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region (typically 'global' for Front Door)"
  type        = string
  default     = "global"
}

variable "front_door_name" {
  description = "Name of the Front Door profile (must be globally unique)"
  type        = string
}

variable "friendly_name" {
  description = "Friendly name for the Front Door profile"
  type        = string
  default     = null
}

variable "load_balancer_enabled" {
  description = "Enable load balancing"
  type        = bool
  default     = true
}

variable "backend_pools" {
  description = <<-EOT
    List of backend pools.
    
    Example:
    backend_pools = [
      {
        name                = "web-backend"
        health_probe_name   = "http-probe"
        load_balancing_name = "lb-settings"
        backends = [
          {
            host_header = "www.example.com"
            address     = "10.0.1.10"
            http_port   = 80
            https_port  = 443
            priority    = 1
            weight      = 50
            enabled     = true
          }
        ]
      }
    ]
  EOT
  type = list(object({
    name                = string
    health_probe_name   = string
    load_balancing_name = string
    backends = list(object({
      host_header = string
      address     = string
      http_port   = number
      https_port  = number
      priority    = optional(number, 1)
      weight      = optional(number, 50)
      enabled     = optional(bool, true)
    }))
  }))
  default = []
}

variable "backend_pool_health_probes" {
  description = <<-EOT
    List of health probes for backend pools.
    
    Example:
    backend_pool_health_probes = [
      {
        name                = "http-probe"
        protocol            = "Http"
        path                = "/health"
        interval_in_seconds = 30
        enabled             = true
      }
    ]
  EOT
  type = list(object({
    name                = string
    protocol            = string # "Http" or "Https"
    path                = string
    interval_in_seconds = number
    enabled             = optional(bool, true)
  }))
  default = []
}

variable "backend_pool_load_balancing" {
  description = <<-EOT
    List of load balancing settings.
    
    Example:
    backend_pool_load_balancing = [
      {
        name                            = "lb-settings"
        sample_size                     = 4
        successful_samples_required     = 2
        additional_latency_milliseconds = 0
      }
    ]
  EOT
  type = list(object({
    name                            = string
    sample_size                     = number
    successful_samples_required     = number
    additional_latency_milliseconds = number
  }))
  default = []
}

variable "frontend_endpoints" {
  description = <<-EOT
    List of frontend endpoints.
    
    Example:
    frontend_endpoints = [
      {
        name      = "www-endpoint"
        host_name = "www.example.com"
        session_affinity_enabled = false
        session_affinity_ttl_seconds = 0
        web_application_firewall_policy_link_id = null
      }
    ]
  EOT
  type = list(object({
    name                                    = string
    host_name                               = string
    session_affinity_enabled                = optional(bool, false)
    session_affinity_ttl_seconds            = optional(number, 0)
    web_application_firewall_policy_link_id = optional(string, null)
  }))
  default = []
}

variable "routing_rules" {
  description = <<-EOT
    List of routing rules.
    
    Example (Forwarding):
    routing_rules = [
      {
        name               = "http-rule"
        frontend_endpoints  = ["www-endpoint"]
        accepted_protocols = ["Http", "Https"]
        patterns_to_match  = ["/*"]
        enabled            = true
        route_configuration = {
          forwarding_protocol = "MatchRequest"
          backend_pool_name   = "web-backend"
          cache_enabled       = false
        }
      }
    ]
    
    Example (Redirect):
    routing_rules = [
      {
        name               = "redirect-rule"
        frontend_endpoints  = ["www-endpoint"]
        accepted_protocols = ["Http"]
        patterns_to_match  = ["/*"]
        enabled            = true
        route_configuration = {
          redirect_type     = "Moved"
          redirect_protocol = "HttpsOnly"
          redirect_host     = "www.example.com"
          redirect_path     = "/{path}"
          redirect_query_string = "{query}"
        }
      }
    ]
  EOT
  type = list(object({
    name               = string
    frontend_endpoints = list(string)
    accepted_protocols = list(string) # "Http", "Https"
    patterns_to_match  = list(string)
    enabled            = optional(bool, true)
    route_configuration = object({
      # Forwarding Configuration
      forwarding_protocol                   = optional(string, null) # "HttpOnly", "HttpsOnly", "MatchRequest"
      backend_pool_name                     = optional(string, null)
      cache_enabled                         = optional(bool, false)
      cache_query_parameter_strip_directive = optional(string, "StripNone")
      cache_duration                        = optional(string, null)
      compression_enabled                   = optional(bool, false)
      forwarding_path                       = optional(string, null)
      # Redirect Configuration
      redirect_type         = optional(string, null) # "Moved", "Found", "TemporaryRedirect", "PermanentRedirect"
      redirect_protocol     = optional(string, null) # "HttpOnly", "HttpsOnly", "MatchRequest"
      redirect_host         = optional(string, null)
      redirect_path         = optional(string, null)
      redirect_query_string = optional(string, null)
      redirect_fragment     = optional(string, null)
    })
  }))
  default = []
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

