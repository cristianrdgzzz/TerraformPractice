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


provider "tls" {}

# Generate an SSH private key for secure VM authentication
# This key pair will be used to connect to the virtual machine
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an Azure Resource Group
# Resource groups are logical containers for resources in Azure
resource "azurerm_resource_group" "example" {
  name     = "rg-terraform-example"
  location = "northeurope"
}

# Create an Azure Virtual Network
# VNets provide isolated network environments where resources can communicate
resource "azurerm_virtual_network" "example" {
  name                = "vnet-terraform-example"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# Create a subnet within the virtual network
# Subnets divide the VNet address space into smaller network segments
resource "azurerm_subnet" "internal" {
  name                 = "subnet-terraform-example"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create a Network Interface
# NICs connect virtual machines to subnets and handle IP configuration
resource "azurerm_network_interface" "example" {
  name                = "nic-terraform-example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create a Linux Virtual Machine
# This is the compute resource that will run your workloads
resource "azurerm_linux_virtual_machine" "example" {
  name                = "vm-terraform-example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  size                = "Standard_B1s"

  admin_username = "azureuser"

  # Configure SSH key authentication for secure access
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example.public_key_openssh
  }

  # Attach the network interface to the VM
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  depends_on = [
    azurerm_network_interface.example
  ]

  # Configure the OS disk
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Specify the OS image (Ubuntu 22.04 LTS)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
