# ============================================================================
# Global Distribution Example
# ============================================================================
# This example demonstrates global content distribution using:
# - Azure Front Door for global load balancing and WAF
# - Azure CDN for static content caching
# - Traffic Manager for DNS-based routing
# - Application Gateway in multiple regions
#
# Architecture:
# - Multiple regions (East US, West Europe)
# - Front Door for global entry point
# - CDN for static assets
# - Traffic Manager for failover
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
# Resource Groups (Multiple Regions)
# ----------------------------------------------------------------------------
resource "azurerm_resource_group" "eastus" {
  name     = "rg-global-eastus"
  location = "eastus"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
    Region      = "EastUS"
  }
}

resource "azurerm_resource_group" "westeurope" {
  name     = "rg-global-westeurope"
  location = "westeurope"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
    Region      = "WestEurope"
  }
}

# ----------------------------------------------------------------------------
# Public IPs for Application Gateways (Multiple Regions)
# ----------------------------------------------------------------------------
resource "azurerm_public_ip" "appgw_eastus" {
  name                = "pip-appgw-eastus"
  location            = azurerm_resource_group.eastus.location
  resource_group_name = azurerm_resource_group.eastus.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_public_ip" "appgw_westeurope" {
  name                = "pip-appgw-westeurope"
  location            = azurerm_resource_group.westeurope.location
  resource_group_name = azurerm_resource_group.westeurope.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Virtual Networks (Multiple Regions)
# ----------------------------------------------------------------------------
module "vnet_eastus" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.eastus.name
  location            = azurerm_resource_group.eastus.location
  vnet_name           = "vnet-global-eastus"
  address_space       = ["10.1.0.0/16"]

  subnets = {
    "appgw-subnet" = {
      address_prefixes = ["10.1.1.0/24"]
    }
    "web-subnet" = {
      address_prefixes = ["10.1.2.0/24"]
    }
  }

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
    Region      = "EastUS"
  }
}

module "vnet_westeurope" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.westeurope.name
  location            = azurerm_resource_group.westeurope.location
  vnet_name           = "vnet-global-westeurope"
  address_space       = ["10.2.0.0/16"]

  subnets = {
    "appgw-subnet" = {
      address_prefixes = ["10.2.1.0/24"]
    }
    "web-subnet" = {
      address_prefixes = ["10.2.2.0/24"]
    }
  }

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
    Region      = "WestEurope"
  }
}

# ----------------------------------------------------------------------------
# Application Gateways (Multiple Regions)
# ----------------------------------------------------------------------------
module "app_gateway_eastus" {
  source = "../../modules/application-gateway"

  resource_group_name      = azurerm_resource_group.eastus.name
  location                 = azurerm_resource_group.eastus.location
  application_gateway_name = "appgw-eastus"

  sku_name     = "Standard_v2"
  sku_tier     = "Standard_v2"
  sku_capacity = null

  autoscale_configuration = {
    min_capacity = 2
    max_capacity = 10
  }

  gateway_ip_configuration = {
    name      = "appgw-ip-config"
    subnet_id = module.vnet_eastus.subnet_ids["appgw-subnet"]
  }

  frontend_ip_configurations = [
    {
      name                 = "public-frontend"
      public_ip_address_id = azurerm_public_ip.appgw_eastus.id
    }
  ]

  frontend_ports = [
    {
      name = "http-port"
      port = 80
    }
  ]

  backend_address_pools = [
    {
      name         = "web-backend"
      ip_addresses = ["10.1.2.10", "10.1.2.11"]
      fqdns        = []
    }
  ]

  backend_http_settings = [
    {
      name                                = "http-setting"
      cookie_based_affinity               = "Disabled"
      path                                = "/"
      port                                = 80
      protocol                            = "Http"
      request_timeout                     = 20
      probe_name                          = "http-probe"
      pick_host_name_from_backend_address = true
    }
  ]

  http_listeners = [
    {
      name                           = "http-listener"
      frontend_ip_configuration_name = "public-frontend"
      frontend_port_name             = "http-port"
      protocol                       = "Http"
    }
  ]

  request_routing_rules = [
    {
      name                       = "http-rule"
      rule_type                  = "Basic"
      http_listener_name         = "http-listener"
      backend_address_pool_name  = "web-backend"
      backend_http_settings_name = "http-setting"
    }
  ]

  probes = [
    {
      name                                      = "http-probe"
      protocol                                  = "Http"
      path                                      = "/health"
      interval                                  = 30
      timeout                                   = 30
      unhealthy_threshold                       = 3
      pick_host_name_from_backend_http_settings = true
      match = {
        status_codes = ["200-399"]
      }
    }
  ]

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
    Region      = "EastUS"
  }
}

module "app_gateway_westeurope" {
  source = "../../modules/application-gateway"

  resource_group_name      = azurerm_resource_group.westeurope.name
  location                 = azurerm_resource_group.westeurope.location
  application_gateway_name = "appgw-westeurope"

  sku_name     = "Standard_v2"
  sku_tier     = "Standard_v2"
  sku_capacity = null

  autoscale_configuration = {
    min_capacity = 2
    max_capacity = 10
  }

  gateway_ip_configuration = {
    name      = "appgw-ip-config"
    subnet_id = module.vnet_westeurope.subnet_ids["appgw-subnet"]
  }

  frontend_ip_configurations = [
    {
      name                 = "public-frontend"
      public_ip_address_id = azurerm_public_ip.appgw_westeurope.id
    }
  ]

  frontend_ports = [
    {
      name = "http-port"
      port = 80
    }
  ]

  backend_address_pools = [
    {
      name         = "web-backend"
      ip_addresses = ["10.2.2.10", "10.2.2.11"]
      fqdns        = []
    }
  ]

  backend_http_settings = [
    {
      name                                = "http-setting"
      cookie_based_affinity               = "Disabled"
      path                                = "/"
      port                                = 80
      protocol                            = "Http"
      request_timeout                     = 20
      probe_name                          = "http-probe"
      pick_host_name_from_backend_address = true
    }
  ]

  http_listeners = [
    {
      name                           = "http-listener"
      frontend_ip_configuration_name = "public-frontend"
      frontend_port_name             = "http-port"
      protocol                       = "Http"
    }
  ]

  request_routing_rules = [
    {
      name                       = "http-rule"
      rule_type                  = "Basic"
      http_listener_name         = "http-listener"
      backend_address_pool_name  = "web-backend"
      backend_http_settings_name = "http-setting"
    }
  ]

  probes = [
    {
      name                                      = "http-probe"
      protocol                                  = "Http"
      path                                      = "/health"
      interval                                  = 30
      timeout                                   = 30
      unhealthy_threshold                       = 3
      pick_host_name_from_backend_http_settings = true
      match = {
        status_codes = ["200-399"]
      }
    }
  ]

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
    Region      = "WestEurope"
  }
}

# ----------------------------------------------------------------------------
# Traffic Manager Profile
# ----------------------------------------------------------------------------
# DNS-based load balancer for failover between regions
# ----------------------------------------------------------------------------
module "traffic_manager" {
  source = "../../modules/traffic-manager"

  resource_group_name = azurerm_resource_group.eastus.name
  location            = "global"

  traffic_manager_profile_name = "tm-global-app"
  traffic_routing_method       = "Priority" # Failover routing

  dns_config = {
    relative_name = "global-app"
    ttl           = 60
  }

  monitor_config = {
    protocol                     = "HTTPS"
    port                         = 443
    path                         = "/health"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
    expected_status_code_ranges  = ["200-299"]
  }

  endpoints = [
    {
      name               = "eastus-endpoint"
      type               = "azureEndpoints"
      target_resource_id = azurerm_public_ip.appgw_eastus.id
      priority           = 1 # Primary
      weight             = null
      enabled            = true
    },
    {
      name               = "westeurope-endpoint"
      type               = "azureEndpoints"
      target_resource_id = azurerm_public_ip.appgw_westeurope.id
      priority           = 2 # Secondary (failover)
      weight             = null
      enabled            = true
    }
  ]

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# CDN Profile and Endpoint
# ----------------------------------------------------------------------------
# Content Delivery Network for static assets
# ----------------------------------------------------------------------------
module "cdn" {
  source = "../../modules/cdn"

  resource_group_name = azurerm_resource_group.eastus.name
  location            = "global"

  cdn_profile_name = "cdn-global-app"
  sku              = "Standard_Microsoft"

  cdn_endpoints = {
    "static-assets" = {
      name               = "cdn-static"
      origin_host_header = null
      origins = [
        {
          name       = "storage-origin"
          host_name  = "storageaccount.blob.core.windows.net" # Replace with your storage account
          http_port  = 80
          https_port = 443
        }
      ]
      is_http_allowed               = false
      is_https_allowed              = true
      querystring_caching_behaviour = "IgnoreQueryString"
      is_compression_enabled        = true
      content_types_to_compress     = ["text/html", "text/css", "application/javascript", "text/javascript"]
      optimization_type             = "GeneralWebDelivery"
    }
  }

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Front Door Profile
# ----------------------------------------------------------------------------
# Global entry point with WAF and edge caching
# Note: Front Door uses different resource types in newer versions
# This example uses the classic Front Door resource
# ----------------------------------------------------------------------------
module "front_door" {
  source = "../../modules/front-door"

  resource_group_name = azurerm_resource_group.eastus.name
  location            = "global"

  front_door_name = "fd-global-app"
  friendly_name   = "Global Application Front Door"

  load_balancer_enabled = true

  backend_pools = [
    {
      name                = "eastus-backend"
      health_probe_name   = "http-probe"
      load_balancing_name = "lb-settings"
      backends = [
        {
          host_header = azurerm_public_ip.appgw_eastus.ip_address
          address     = azurerm_public_ip.appgw_eastus.ip_address
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
          enabled     = true
        }
      ]
    },
    {
      name                = "westeurope-backend"
      health_probe_name   = "http-probe"
      load_balancing_name = "lb-settings"
      backends = [
        {
          host_header = azurerm_public_ip.appgw_westeurope.ip_address
          address     = azurerm_public_ip.appgw_westeurope.ip_address
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
          enabled     = true
        }
      ]
    }
  ]

  backend_pool_health_probes = [
    {
      name                = "http-probe"
      protocol            = "Http"
      path                = "/health"
      interval_in_seconds = 30
      enabled             = true
    }
  ]

  backend_pool_load_balancing = [
    {
      name                            = "lb-settings"
      sample_size                     = 4
      successful_samples_required     = 2
      additional_latency_milliseconds = 0
    }
  ]

  frontend_endpoints = [
    {
      name                                    = "www-endpoint"
      host_name                               = "www.example.com" # Replace with your domain
      session_affinity_enabled                = false
      session_affinity_ttl_seconds            = 0
      web_application_firewall_policy_link_id = null
    }
  ]

  routing_rules = [
    {
      name               = "http-rule"
      frontend_endpoints = ["www-endpoint"]
      accepted_protocols = ["Http", "Https"]
      patterns_to_match  = ["/*"]
      enabled            = true
      route_configuration = {
        forwarding_protocol = "MatchRequest"
        backend_pool_name   = "eastus-backend"
        cache_enabled       = false
      }
    }
  ]

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

