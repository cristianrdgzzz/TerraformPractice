# ============================================================================
# Multi-Tier Application Example
# ============================================================================
# This example demonstrates a complete multi-tier application architecture
# with Application Gateway, Load Balancer, and proper network segmentation.
#
# Architecture:
# - Resource Group
# - Virtual Network with multiple subnets
# - Application Gateway (Layer 7) for web tier
# - Load Balancer (Layer 4) for application tier
# - Network Security Groups for each tier
# - NAT Gateway for outbound connectivity
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
# Resource Group
# ----------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-multi-tier-app"
  location = "eastus"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Virtual Network Module
# ----------------------------------------------------------------------------
# Creates the base network infrastructure with subnets for each tier
# ----------------------------------------------------------------------------
module "vnet" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_name           = "vnet-multi-tier"
  address_space       = ["10.0.0.0/16"]

  subnets = {
    "appgw-subnet" = {
      address_prefixes = ["10.0.1.0/24"]
      # Application Gateway requires a dedicated subnet
    }
    "web-subnet" = {
      address_prefixes = ["10.0.2.0/24"]
    }
    "app-subnet" = {
      address_prefixes = ["10.0.3.0/24"]
    }
    "db-subnet" = {
      address_prefixes = ["10.0.4.0/24"]
    }
    "nat-subnet" = {
      address_prefixes = ["10.0.5.0/24"]
    }
  }

  network_security_groups = {
    "web-nsg" = {
      rules = [
        {
          name                       = "AllowHTTPFromAppGW"
          priority                   = 1000
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "80"
          source_address_prefix      = "10.0.1.0/24"
          destination_address_prefix = "*"
        },
        {
          name                       = "AllowHTTPSFromAppGW"
          priority                   = 1001
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "10.0.1.0/24"
          destination_address_prefix = "*"
        }
      ]
      associate_to_subnets = ["web-subnet"]
    }
    "app-nsg" = {
      rules = [
        {
          name                       = "AllowFromWebSubnet"
          priority                   = 1000
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "10.0.2.0/24"
          destination_address_prefix = "*"
        }
      ]
      associate_to_subnets = ["app-subnet"]
    }
    "db-nsg" = {
      rules = [
        {
          name                       = "AllowFromAppSubnet"
          priority                   = 1000
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "3306"
          source_address_prefix      = "10.0.3.0/24"
          destination_address_prefix = "*"
        }
      ]
      associate_to_subnets = ["db-subnet"]
    }
  }

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Public IP for Application Gateway
# ----------------------------------------------------------------------------
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-multi-tier"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Application Gateway Module
# ----------------------------------------------------------------------------
# Layer 7 load balancer for web tier
# Provides SSL termination, WAF, and URL-based routing
# ----------------------------------------------------------------------------
module "app_gateway" {
  source = "../../modules/application-gateway"

  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  application_gateway_name = "appgw-multi-tier"

  sku_name     = "WAF_v2"
  sku_tier     = "WAF_v2"
  sku_capacity = null # Autoscaling

  autoscale_configuration = {
    min_capacity = 2
    max_capacity = 10
  }

  gateway_ip_configuration = {
    name      = "appgw-ip-config"
    subnet_id = module.vnet.subnet_ids["appgw-subnet"]
  }

  frontend_ip_configurations = [
    {
      name                 = "public-frontend"
      public_ip_address_id = azurerm_public_ip.appgw.id
    }
  ]

  frontend_ports = [
    {
      name = "http-port"
      port = 80
    },
    {
      name = "https-port"
      port = 443
    }
  ]

  backend_address_pools = [
    {
      name         = "web-backend"
      ip_addresses = ["10.0.2.10", "10.0.2.11"] # Web tier VMs
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

  waf_configuration = {
    enabled                  = true
    firewall_mode            = "Prevention"
    rule_set_type            = "OWASP"
    rule_set_version         = "3.2"
    file_upload_limit_mb     = 100
    max_request_body_size_kb = 128
    request_body_check       = true
  }

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Public IP for Load Balancer
# ----------------------------------------------------------------------------
resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-multi-tier"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Load Balancer Module
# ----------------------------------------------------------------------------
# Layer 4 load balancer for application tier
# Distributes traffic to application servers
# ----------------------------------------------------------------------------
module "load_balancer" {
  source = "../../modules/load-balancer"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  load_balancer_name  = "lb-multi-tier"

  sku      = "Standard"
  sku_tier = "Regional"

  frontend_ip_configurations = [
    {
      name                 = "public-frontend"
      public_ip_address_id = azurerm_public_ip.lb.id
    }
  ]

  backend_address_pools = [
    {
      name = "app-backend"
    }
  ]

  probes = [
    {
      name                = "tcp-probe"
      protocol            = "Tcp"
      port                = 8080
      interval_in_seconds = 5
      number_of_probes    = 2
    }
  ]

  load_balancing_rules = [
    {
      name                           = "app-rule"
      protocol                       = "Tcp"
      frontend_port                  = 8080
      backend_port                   = 8080
      frontend_ip_configuration_name = "public-frontend"
      backend_address_pool_name      = "app-backend"
      probe_name                     = "tcp-probe"
      idle_timeout_in_minutes        = 4
      load_distribution              = "Default"
    }
  ]

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Public IP for NAT Gateway
# ----------------------------------------------------------------------------
resource "azurerm_public_ip" "nat_gateway" {
  name                = "pip-nat-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# NAT Gateway Module
# ----------------------------------------------------------------------------
# Provides outbound connectivity for VMs in private subnets
# All outbound traffic from web, app, and db subnets goes through NAT
# ----------------------------------------------------------------------------
module "nat_gateway" {
  source = "../../modules/nat-gateway"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  nat_gateway_name    = "nat-multi-tier"

  # Public IP IDs (must be Standard SKU)
  public_ip_address_ids = [azurerm_public_ip.nat_gateway.id]

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# NAT Gateway Subnet Associations
# ----------------------------------------------------------------------------
# Associate NAT Gateway with subnets that need outbound connectivity
# ----------------------------------------------------------------------------
resource "azurerm_subnet_nat_gateway_association" "web" {
  subnet_id      = module.vnet.subnet_ids["web-subnet"]
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

resource "azurerm_subnet_nat_gateway_association" "app" {
  subnet_id      = module.vnet.subnet_ids["app-subnet"]
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

resource "azurerm_subnet_nat_gateway_association" "db" {
  subnet_id      = module.vnet.subnet_ids["db-subnet"]
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

