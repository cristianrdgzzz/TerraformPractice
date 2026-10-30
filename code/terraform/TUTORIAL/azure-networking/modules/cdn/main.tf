# ============================================================================
# Azure CDN Module - Main Configuration
# ============================================================================
# Azure CDN delivers content to users with high bandwidth by caching content
# at edge locations close to users.
#
# Architecture:
# Origin Server
#     ↓
# CDN Profile
#     ↓
# CDN Endpoints (Edge Locations)
#     ├── Edge Location 1 (US)
#     ├── Edge Location 2 (Europe)
#     └── Edge Location 3 (Asia)
#     ↓
# Users (Fast Content Delivery)
# ============================================================================

# ----------------------------------------------------------------------------
# CDN Profile
# ----------------------------------------------------------------------------
# CDN Profile is a logical grouping of CDN endpoints.
# It defines the CDN provider (Microsoft, Verizon, Akamai) and pricing tier.
#
# SKU Options:
# - Standard_Microsoft: Microsoft's CDN, good performance
# - Standard_Verizon: Verizon CDN, good for large scale
# - Standard_Akamai: Akamai CDN, good for dynamic content
# - Premium_Verizon: Verizon with advanced features
# - Premium_Microsoft: Microsoft with advanced features
# ----------------------------------------------------------------------------
resource "azurerm_cdn_profile" "main" {
  name                = var.cdn_profile_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  tags = var.tags
}

# ----------------------------------------------------------------------------
# CDN Endpoints
# ----------------------------------------------------------------------------
# CDN Endpoints are the actual content delivery points.
# They cache content from origin servers and serve it to users.
#
# Key Features:
# - Content caching at edge locations
# - Compression
# - HTTPS support
# - Custom domain support
# - Geo-filtering
# - Query string handling
# ----------------------------------------------------------------------------
resource "azurerm_cdn_endpoint" "main" {
  for_each = var.cdn_endpoints

  name                = each.value.name
  profile_name        = azurerm_cdn_profile.main.name
  location            = var.location
  resource_group_name = var.resource_group_name
  origin_host_header  = each.value.origin_host_header

  # Origins (source servers)
  dynamic "origin" {
    for_each = each.value.origins
    content {
      name       = origin.value.name
      host_name  = origin.value.host_name
      http_port  = origin.value.http_port
      https_port = origin.value.https_port
    }
  }

  # Protocol Settings
  is_http_allowed  = each.value.is_http_allowed
  is_https_allowed = each.value.is_https_allowed

  # Caching
  querystring_caching_behaviour = each.value.querystring_caching_behaviour

  # Compression
  is_compression_enabled    = each.value.is_compression_enabled
  content_types_to_compress = each.value.content_types_to_compress

  # Optimization
  optimization_type = each.value.optimization_type

  # Geo-filtering
  dynamic "geo_filter" {
    for_each = each.value.geo_filter != null ? each.value.geo_filter : []
    content {
      relative_path = geo_filter.value.relative_path
      action        = geo_filter.value.action
      country_codes = geo_filter.value.country_codes
    }
  }

  tags = merge(var.tags, each.value.tags)
}

