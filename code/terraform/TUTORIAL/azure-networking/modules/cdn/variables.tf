# ============================================================================
# Azure CDN Module - Variables
# ============================================================================
# Azure CDN delivers content to users with high bandwidth by caching content
# at edge locations close to users.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region (typically 'global' for CDN)"
  type        = string
  default     = "global"
}

variable "cdn_profile_name" {
  description = "Name of the CDN profile"
  type        = string
}

variable "sku" {
  description = "CDN profile SKU. Options: 'Standard_Akamai', 'Standard_Verizon', 'Standard_Microsoft', 'Premium_Verizon', 'Premium_Microsoft'"
  type        = string
  default     = "Standard_Microsoft"

  validation {
    condition = contains([
      "Standard_Akamai",
      "Standard_Verizon",
      "Standard_Microsoft",
      "Premium_Verizon",
      "Premium_Microsoft"
    ], var.sku)
    error_message = "SKU must be one of: Standard_Akamai, Standard_Verizon, Standard_Microsoft, Premium_Verizon, Premium_Microsoft."
  }
}

variable "cdn_endpoints" {
  description = <<-EOT
    Map of CDN endpoints to create.
    
    Example:
    cdn_endpoints = {
      "web-endpoint" = {
        name                = "cdn-web"
        origin_host_header = "www.example.com"
        origins = [
          {
            name      = "web-origin"
            host_name = "www.example.com"
            http_port = 80
            https_port = 443
          }
        ]
        is_http_allowed = true
        is_https_allowed = true
        querystring_caching_behaviour = "IgnoreQueryString"
        content_types_to_compress = ["text/html", "text/css", "application/javascript"]
        is_compression_enabled = true
        geo_filter = []
        optimization_type = "GeneralWebDelivery"
      }
    }
  EOT
  type = map(object({
    name               = string
    origin_host_header = optional(string, null)
    origins = list(object({
      name       = string
      host_name  = string
      http_port  = number
      https_port = number
    }))
    is_http_allowed               = optional(bool, true)
    is_https_allowed              = optional(bool, true)
    querystring_caching_behaviour = optional(string, "IgnoreQueryString")
    content_types_to_compress     = optional(list(string), [])
    is_compression_enabled        = optional(bool, false)
    optimization_type             = optional(string, "GeneralWebDelivery")
    geo_filter = optional(list(object({
      relative_path = string
      action        = string # "Allow" or "Block"
      country_codes = list(string)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

