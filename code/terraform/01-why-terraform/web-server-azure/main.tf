
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



# Generate an SSH private key for secure VM access
resource "tls_private_key" "app" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#######1
# Define an Azure Resource Group
# Resource groups are containers that hold related resources for an Azure solution
resource "azurerm_resource_group" "app" {
  name     = "rg-webserver-app"
  location = "East US"
}

######2
# Define an Azure Virtual Network
# Virtual networks provide isolated network environments for your resources
resource "azurerm_virtual_network" "app" {
  name                = "vnet-webserver-app"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
}


# Define a subnet within the virtual network
# Subnets allow you to segment the virtual network into smaller networks
resource "azurerm_subnet" "internal" {
  name                 = "subnet-webserver-app"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Define a public IP address
# This IP address will be assigned to the VM for external access via HTTP
resource "azurerm_public_ip" "app" {
  name                = "pip-webserver-app"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Define a Network Security Group to control traffic
# NSGs act as virtual firewalls to control inbound and outbound traffic
resource "azurerm_network_security_group" "app" {
  name                = "nsg-webserver-app"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

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

  security_rule {
    name                       = "AllowSSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# Define a network interface
# Network interfaces attach VMs to subnets and manage IP configurations
resource "azurerm_network_interface" "app" {
  name                = "nic-webserver-app"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

# Define a Linux Virtual Machine
# This is the core compute resource that will run Apache web server
resource "azurerm_linux_virtual_machine" "app" {
  name                = "vm-webserver-app"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  size                = "Standard_B2ls_v2"

  admin_username = "azureuser"

  # Configure SSH key authentication for secure access
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.app.public_key_openssh
  }

  network_interface_ids = [
    azurerm_network_interface.app.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Install and start Apache web server using custom script
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              systemctl start apache2
              systemctl enable apache2
              EOF
  )
}
