# ============================================================================
# Deploying a Cluster of Web Servers on Azure
# ============================================================================
# This example demonstrates how to deploy multiple web servers using
# Virtual Machine Scale Sets (VMSS) in Azure. VMSS allows for:
# - Automatic scaling based on demand
# - Load distribution across multiple servers
# - High availability and fault tolerance
# ============================================================================


#Primero terraform y el provider de Azure 
terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  # Configuración del backend para almacenar el estado de Terraform en Azure Storage
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttflibro1855"
    container_name       = "tfstate"
    key                  = "01-web-server-azure.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}



# ============================================================================
# Create Azure Resource Group
# ============================================================================
# A resource group is a logical container that holds all resources
# deployed for this application. All resources will be created within
# this group in the specified region.
# ============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}



# ============================================================================
# Create Virtual Network (VNet)
# ============================================================================
# The VNet provides a private network space for our resources.
# We use a Class B private address space (10.0.0.0/16) which gives us
# 65,536 possible addresses for our infrastructure.
# ============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${var.environment}-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# Create Subnet
# ============================================================================
# A subnet is a subdivision of the VNet where actual resources are deployed.
# We allocate a /24 subnet which provides 256 addresses (250 usable).
# This is sufficient for our web server cluster with automatic scaling.
# ============================================================================

resource "azurerm_subnet" "main" {
  name                 = "${var.environment}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_address_prefixes]
}

# ============================================================================
# Create Network Security Group (NSG)
# ============================================================================
# The NSG acts as a virtual firewall that controls inbound and outbound
# traffic to resources. We configure it to allow:
# - HTTP traffic (port 80) from anywhere
# - HTTPS traffic (port 443) from anywhere
# - SSH traffic (port 22) from anywhere for management purposes
# ============================================================================

resource "azurerm_network_security_group" "main" {
  name                = "${var.environment}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow HTTP traffic
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.server_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTPS traffic
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow SSH traffic for management
  security_rule {
    name                       = "AllowSSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# Associate NSG with Subnet
# ============================================================================
# This links the Network Security Group to the subnet, ensuring all network
# traffic to/from resources in this subnet is controlled by the NSG rules.
# ============================================================================

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}


