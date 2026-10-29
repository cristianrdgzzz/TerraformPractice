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
    resource_group_name = "rg-terraform-state"
    storage_account_name = "sttflibro1855"
    container_name = "tfstate"
    key = "01-web-server-azure.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}



provider "tls" {}

# ============================================================================
# Generate SSH Key for VM Authentication
# ============================================================================
# Creates an RSA 4096-bit private key that will be used to authenticate
# against all virtual machines in the cluster. The public key will be
# installed on each VM during provisioning.
# ============================================================================

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
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
    destination_port_range     = "80"
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

# ============================================================================
# Create Virtual Machine Scale Set (VMSS)
# ============================================================================
# VMSS is an Azure compute resource that lets you create and manage a
# group of identical, load-balanced VMs. Key features:
# - Automatic scaling: adds/removes VMs based on demand
# - Automatic updates: manages OS and application updates
# - Load balancing: distributes traffic across all instances
# - High availability: spreads instances across availability zones
#
# In this example, we deploy:
# - Ubuntu 22.04 LTS as the base image
# - Standard_B2s VM size (2 vCPUs, 4 GB RAM)
# - Initial count of 2 instances, auto-scaling up to 5
# ============================================================================

resource "azurerm_linux_virtual_machine_scale_set" "web_servers" {
  name                = "${var.environment}-web-vmss"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.vm_size

  # Set initial instance count
  instances = var.instance_count

  # Configure administrator account
  admin_username = "azureuser"

  # Use SSH key authentication (more secure than passwords)
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.main.public_key_openssh
  }

  # Configure the OS disk
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Specify the operating system image
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Configure network interface
  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name      = "ipconfig"
      subnet_id = azurerm_subnet.main.id
      primary   = true
    }
  }

  # Install and configure web server on startup
  # This script runs on each VM instance to install Apache2 and create
  # a simple HTML page that displays the instance hostname
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              systemctl start apache2
              systemctl enable apache2

              # Create a simple health check page
              HOSTNAME=$(hostname)
              echo "<h1>Web Server Cluster Demo</h1>" > /var/www/html/index.html
              echo "<p>Hostname: $HOSTNAME</p>" >> /var/www/html/index.html
              echo "<p>Deployed with Terraform on Azure</p>" >> /var/www/html/index.html
              EOF
  )

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# Configure Autoscaling
# ============================================================================
# Autoscaling automatically adjusts the number of VM instances based on
# CPU usage. This ensures optimal performance and cost efficiency:
#
# - Scale Out: When average CPU exceeds 70% for 5 minutes, add 1 instance
# - Scale In: When average CPU drops below 30% for 5 minutes, remove 1 instance
# - Min instances: 2 (minimum for availability)
# - Max instances: 5 (cost control limit)
# ============================================================================

resource "azurerm_monitor_autoscale_setting" "web_servers" {
  name                = "${var.environment}-web-autoscale"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web_servers.id

  profile {
    name = "Scale based on CPU"

    capacity {
      minimum = var.instance_count
      maximum = var.max_instance_count
      default = var.instance_count
    }

    # Rule to scale out (add instances)
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_servers.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    # Rule to scale in (remove instances)
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_servers.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}
