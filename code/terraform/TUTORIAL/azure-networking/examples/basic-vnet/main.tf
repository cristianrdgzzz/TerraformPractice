# ============================================================================
# Basic Virtual Network Example
# ============================================================================
# This example demonstrates how to create a basic Azure Virtual Network
# with subnets and Network Security Groups.
#
# Architecture:
# - Resource Group
# - Virtual Network (10.0.0.0/16)
#   - Web Subnet (10.0.1.0/24) with NSG
#   - App Subnet (10.0.2.0/24) with NSG
#   - DB Subnet (10.0.3.0/24) with NSG
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
# Resource groups are containers for Azure resources.
# All resources in this example will be created in this resource group.
# ----------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-basic-vnet-example"
  location = "eastus"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Virtual Network Module
# ----------------------------------------------------------------------------
# This module creates a complete VNet infrastructure:
# - Virtual Network with address space
# - Subnets for different tiers
# - Network Security Groups with rules
# - Route tables (optional, not used in this example)
# ----------------------------------------------------------------------------
module "vnet" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_name           = "vnet-basic-example"
  address_space       = ["10.0.0.0/16"]

  # Subnet Configuration
  # Each subnet represents a different tier of the application:
  # - Web: Public-facing web servers
  # - App: Application servers (internal)
  # - DB: Database servers (most restricted)
  subnets = {
    "web-subnet" = {
      address_prefixes = ["10.0.1.0/24"]
      # Service endpoints allow direct access to Azure services
      # without going through the public internet
      service_endpoints = ["Microsoft.Storage", "Microsoft.Sql"]
    }
    "app-subnet" = {
      address_prefixes  = ["10.0.2.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
    "db-subnet" = {
      address_prefixes = ["10.0.3.0/24"]
      # Database subnet typically doesn't need service endpoints
      # as it's the most restricted tier
    }
  }

  # Network Security Group Configuration
  # NSGs act as a firewall at the network level
  network_security_groups = {
    "web-nsg" = {
      rules = [
        # Allow HTTP from internet
        {
          name                       = "AllowHTTPInbound"
          priority                   = 1000
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "80"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        },
        # Allow HTTPS from internet
        {
          name                       = "AllowHTTPSInbound"
          priority                   = 1001
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        },
        # Allow traffic from app subnet
        {
          name                       = "AllowAppSubnet"
          priority                   = 1002
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "10.0.2.0/24"
          destination_address_prefix = "*"
        },
        # Allow all outbound (default, but explicit)
        {
          name                       = "AllowAllOutbound"
          priority                   = 1000
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
      associate_to_subnets = ["web-subnet"]
    }

    "app-nsg" = {
      rules = [
        # Allow traffic from web subnet
        {
          name                       = "AllowWebSubnet"
          priority                   = 1000
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "10.0.1.0/24"
          destination_address_prefix = "*"
        },
        # Allow traffic to DB subnet
        {
          name                       = "AllowDBSubnetOutbound"
          priority                   = 1000
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "3306" # MySQL port
          source_address_prefix      = "*"
          destination_address_prefix = "10.0.3.0/24"
        }
      ]
      associate_to_subnets = ["app-subnet"]
    }

    "db-nsg" = {
      rules = [
        # Only allow traffic from app subnet
        {
          name                       = "AllowAppSubnetInbound"
          priority                   = 1000
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "3306" # MySQL port
          source_address_prefix      = "10.0.2.0/24"
          destination_address_prefix = "*"
        },
        # Deny all other inbound (explicit)
        {
          name                       = "DenyAllInbound"
          priority                   = 4000
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
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

