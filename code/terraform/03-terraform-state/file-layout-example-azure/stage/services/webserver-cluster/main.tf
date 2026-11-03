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
    key                  = "webservercluster.tfstate"
  }
}



variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
  sensitive   = true
}

provider "azurerm" {
  features {}
}


provider "tls" {}

# Generate an SSH private key for secure VM access
# This key is used to configure authentication on all cluster VMs
resource "tls_private_key" "webserver_cluster" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Define an Azure Resource Group
# Resource groups are containers that hold related resources for an Azure solution
resource "azurerm_resource_group" "webserver_cluster" {
  name     = var.resource_group_name
  location = var.location
}

# Define an Azure Virtual Network
# Virtual networks provide isolated network environments for your resources
resource "azurerm_virtual_network" "webserver_cluster" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.webserver_cluster.location
  resource_group_name = azurerm_resource_group.webserver_cluster.name
}

# Define a subnet within the virtual network
# Subnets allow you to segment the virtual network into smaller networks
resource "azurerm_subnet" "webserver_cluster" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.webserver_cluster.name
  virtual_network_name = azurerm_virtual_network.webserver_cluster.name
  address_prefixes     = var.subnet_address_prefixes
}

# Define a Network Security Group to control traffic
# NSGs act as virtual firewalls to control inbound and outbound traffic
resource "azurerm_network_security_group" "webserver_cluster" {
  name                = var.nsg_name
  location            = azurerm_resource_group.webserver_cluster.location
  resource_group_name = azurerm_resource_group.webserver_cluster.name

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
    name                       = "AllowHTTPS"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 102
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
resource "azurerm_subnet_network_security_group_association" "webserver_cluster" {
  subnet_id                 = azurerm_subnet.webserver_cluster.id
  network_security_group_id = azurerm_network_security_group.webserver_cluster.id
}

# Define an Azure Load Balancer
# Load balancers distribute incoming network traffic across multiple VMs
# This provides high availability and improved reliability
resource "azurerm_lb" "webserver_cluster" {
  name                = var.lb_name
  location            = azurerm_resource_group.webserver_cluster.location
  resource_group_name = azurerm_resource_group.webserver_cluster.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.webserver_cluster.id
  }
}

# Define a public IP address for the load balancer
# This IP address will be used to distribute traffic to the cluster
resource "azurerm_public_ip" "webserver_cluster" {
  name                = var.lb_pip_name
  location            = azurerm_resource_group.webserver_cluster.location
  resource_group_name = azurerm_resource_group.webserver_cluster.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Define a backend address pool for the load balancer
# This pool contains all the VMs that will receive traffic
resource "azurerm_lb_backend_address_pool" "webserver_cluster" {
  loadbalancer_id = azurerm_lb.webserver_cluster.id
  name            = "BackendAddressPool"
}

# Define a health probe for the load balancer
# Health probes check the status of backend VMs to ensure they're responding
resource "azurerm_lb_probe" "webserver_cluster" {
  name            = "http-probe"
  loadbalancer_id = azurerm_lb.webserver_cluster.id
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

# Define a load balancer rule
# Rules define how traffic should be distributed to backend VMs
resource "azurerm_lb_rule" "webserver_cluster" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.webserver_cluster.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.webserver_cluster.id]
  probe_id                       = azurerm_lb_probe.webserver_cluster.id
}

# Define a Virtual Machine Scale Set (VMSS)
# VMSS allows you to automatically scale the number of VMs based on demand
# This provides elasticity and high availability for your web tier
resource "azurerm_linux_virtual_machine_scale_set" "webserver_cluster" {
  name                = var.vmss_name
  location            = azurerm_resource_group.webserver_cluster.location
  resource_group_name = azurerm_resource_group.webserver_cluster.name
  sku                 = var.vm_size

  instances = var.instance_count

  admin_username = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.webserver_cluster.public_key_openssh
  }

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

  network_interface {
    name    = "example"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      subnet_id                              = azurerm_subnet.webserver_cluster.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.webserver_cluster.id]
      primary                                = true
    }
  }

  # Install and start a web server with custom configuration
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              systemctl start apache2
              systemctl enable apache2

              # Create a simple health check page
              echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
              EOF
  )

  tags = {
    Environment = "Production"
  }
}

# Define an autoscaling configuration for the VMSS
# This automatically increases or decreases the number of VMs based on CPU usage
resource "azurerm_monitor_autoscale_setting" "webserver_cluster" {
  name                = "autoscale-config"
  resource_group_name = azurerm_resource_group.webserver_cluster.name
  location            = azurerm_resource_group.webserver_cluster.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.webserver_cluster.id

  profile {
    name = "Scale out when CPU increases"

    capacity {
      minimum = var.instance_count
      maximum = var.max_instance_count
      default = var.instance_count
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.webserver_cluster.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
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

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.webserver_cluster.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
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
