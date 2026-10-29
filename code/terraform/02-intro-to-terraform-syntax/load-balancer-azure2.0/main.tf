# ============================================================================
# Deploying a Load Balancer with Backend Pool on Azure
# ============================================================================
# This example demonstrates how to deploy an Azure Load Balancer
# that distributes traffic across multiple backend servers. The load balancer:
# - Distributes incoming traffic across multiple backend VMs
# - Monitors VM health and routes traffic only to healthy servers
# - Provides high availability and improved reliability
# - Enables horizontal scaling by adding/removing backend servers
# ============================================================================

terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}

# ============================================================================
# Create Azure Resource Group
# ============================================================================
# A logical container for all load balancer and backend server resources.
# All resources will be grouped together for easier management and cleanup.
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
# Create Virtual Network
# ============================================================================
# The VNet provides the network infrastructure for load balancer and backends.
# We use a Class B private address space (10.0.0.0/16).
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
# Create Backend Subnet
# ============================================================================
# Dedicated subnet for backend servers behind the load balancer.
# These servers do not have direct internet access by default.
# ============================================================================

resource "azurerm_subnet" "backend" {
  name                 = "${var.environment}-backend-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.backend_subnet_prefix]
}

# ============================================================================
# Create Frontend Subnet
# ============================================================================
# Subnet for the load balancer's frontend configuration.
# The public IP will be placed in this subnet.
# ============================================================================

resource "azurerm_subnet" "frontend" {
  name                 = "${var.environment}-frontend-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.frontend_subnet_prefix]
}

# ============================================================================
# Create Network Security Group for Backend Servers
# ============================================================================
# NSG acts as a virtual firewall controlling traffic to backend servers.
# Configuration:
# - Allows HTTP (port 80) from load balancer subnet
# - Allows HTTPS (port 443) from load balancer subnet
# - Allows SSH (port 22) for management (restrict in production)
# - Denies all other inbound traffic by default
# ============================================================================

resource "azurerm_network_security_group" "backend" {
  name                = "${var.environment}-backend-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow HTTP from load balancer subnet
  security_rule {
    name                       = "AllowHTTPFromLB"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.frontend_subnet_prefix
    destination_address_prefix = "*"
  }

  # Allow HTTPS from load balancer subnet
  security_rule {
    name                       = "AllowHTTPSFromLB"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.frontend_subnet_prefix
    destination_address_prefix = "*"
  }

  # Allow SSH for management (restrict source IP in production)
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
# Associate Backend NSG with Backend Subnet
# ============================================================================
# Links the security group rules to the backend subnet.
# All traffic to/from the backend subnet must comply with these rules.
# ============================================================================

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
}

# ============================================================================
# Create Public IP Address for Load Balancer
# ============================================================================
# The public IP is the entry point for all external traffic.
# This is the IP address clients will connect to.
# Static allocation ensures the IP doesn't change on restart.
# ============================================================================

resource "azurerm_public_ip" "lb" {
  name                = "${var.environment}-lb-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# Create Load Balancer
# ============================================================================
# The load balancer is the central routing component that:
# - Receives incoming traffic on the public IP
# - Distributes traffic to healthy backend servers
# - Monitors backend server health
# - Provides session persistence if configured
#
# Key components:
# - Frontend IP configuration: Public IP entry point
# - Backend address pool: Servers to receive traffic
# - Load balancing rules: How traffic is routed
# - Health probes: Server health monitoring
# ============================================================================

resource "azurerm_lb" "main" {
  name                = "${var.environment}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  # Configure the frontend IP (public-facing entry point)
  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.lb.id
  }

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# Create Backend Address Pool
# ============================================================================
# The backend address pool is a logical group that contains:
# - Network interface IPs of backend servers
# - References to backend VMs or VMSS instances
#
# When a client connects, the load balancer selects a backend
# from this pool and routes the traffic accordingly.
# ============================================================================

resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "backend-address-pool"
}

# ============================================================================
# Create Health Probe
# ============================================================================
# Health probes periodically check backend server responsiveness.
# If a server fails health checks, it is temporarily removed from
# traffic rotation until it becomes healthy again.
#
# Probe Configuration:
# - Protocol: HTTP (can also be TCP or HTTPS)
# - Port: 80 (standard HTTP port)
# - Request Path: "/" (root path used for health check)
# - Interval: 15 seconds between checks
# - Unhealthy Threshold: 2 consecutive failures required to mark unhealthy
#
# This configuration provides a good balance between responsiveness
# and avoiding false positives from temporary network issues.
# ============================================================================

resource "azurerm_lb_probe" "http" {
  name                = "http-health-probe"
  loadbalancer_id     = azurerm_lb.main.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 15
  number_of_probes    = 2
}

# ============================================================================
# Create Load Balancing Rule (HTTP)
# ============================================================================
# Load balancing rules define how traffic flows:
#
# Frontend Configuration:
# - Listens on public IP port 80 (HTTP)
#
# Backend Configuration:
# - Routes to backend pool on port 80
# - Uses configured health probe
# - Distributes using 5-tuple hash algorithm
#   (source IP, source port, dest IP, dest port, protocol)
#
# The rule connects:
# - Frontend IP configuration (public entry point)
# - Backend address pool (private servers)
# - Protocol and ports
# - Health probe (server monitoring)
#
# Features:
# - enable_tcp_reset: Allows graceful connection closure
# - disable_outbound_snat: Better connection handling in some cases
# ============================================================================

resource "azurerm_lb_rule" "http" {
  name                           = "http-load-balancing-rule"
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip-config"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.http.id

  # Enable TCP reset for better connection handling
  enable_tcp_reset = true

  # Disable outbound SNAT for cleaner connection tracking
  disable_outbound_snat = false
}

# ============================================================================
# Create Network Interfaces for Backend Servers
# ============================================================================
# Network interfaces (NICs) connect VMs to the network.
# Each backend VM requires one NIC attached to the backend subnet.
#
# We create multiple NICs using count to demonstrate load balancing
# across multiple servers. In a real deployment, you might use:
# - VM Scale Sets for automatic scaling
# - Or create NICs/VMs one at a time with different names
# ============================================================================

resource "azurerm_network_interface" "backend" {
  count               = var.backend_vm_count
  name                = "${var.environment}-backend-nic-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# Associate Network Interfaces with Backend Address Pool
# ============================================================================
# This association adds the NICs (and thus the VMs) to the backend
# address pool. Once associated, the load balancer begins distributing
# traffic to these backend servers according to the load balancing rules.
# ============================================================================

resource "azurerm_network_interface_backend_address_pool_association" "backend" {
  count                   = var.backend_vm_count
  network_interface_id    = azurerm_network_interface.backend[count.index].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

# ============================================================================
# Create Backend Virtual Machines
# ============================================================================
# Creates the actual VMs that serve application traffic.
#
# VM Specifications:
# - Image: Ubuntu 22.04 LTS (latest generation)
# - Size: Standard_B2s (2 vCPUs, 4 GB RAM) - suitable for light workloads
# - OS Disk: Standard LRS (sufficient for most workloads)
#
# Networking:
# - Attached to backend subnet via NIC
# - Receives traffic through load balancer
# - No direct public IP (private only)
#
# Initialization:
# - Uses provisioner remote-exec to install and configure Apache
# - Creates a simple health check page showing server information
#
# The custom script:
# 1. Updates system packages (apt-get update)
# 2. Installs Apache web server
# 3. Starts Apache and enables it for boot
# 4. Creates index.html showing backend server identification
#
# This enables the load balancer health probes to detect responsive servers.
# ============================================================================

resource "azurerm_virtual_machine" "backend" {
  count               = var.backend_vm_count
  name                = "${var.environment}-backend-vm-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  vm_size             = var.vm_size

  # Automatically delete OS disk when VM is destroyed
  delete_os_disk_on_deletion = true

  # Attach the network interface
  network_interface_ids = [
    azurerm_network_interface.backend[count.index].id,
  ]

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

  # Configure OS profile
  os_profile {
    computer_name  = "backend-${count.index + 1}"
    admin_username = "azureuser"
    admin_password = var.admin_password
  }

  # Disable password authentication (optional - can use SSH keys instead)
  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    Environment = var.environment
    Role        = "backend-server"
  }

  depends_on = [
    azurerm_network_interface.backend
  ]
}

# ============================================================================
# Configure Web Server on Backend VMs
# ============================================================================
# After VMs are created, remotely execute commands to:
# - Update system packages
# - Install Apache web server
# - Start Apache and enable on boot
# - Create a simple health check page
#
# This custom data is essential for the load balancer health probes
# to successfully detect and route traffic to the servers.
# ============================================================================

resource "null_resource" "backend_setup" {
  count = var.backend_vm_count

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y apache2",
      "sudo systemctl start apache2",
      "sudo systemctl enable apache2",
      "echo '<h1>Backend Server ${count.index + 1}</h1>' | sudo tee /var/www/html/index.html",
      "echo '<p>Hostname: '$(hostname)'</p>' | sudo tee -a /var/www/html/index.html",
      "echo '<p>Private IP: '$(hostname -I)'</p>' | sudo tee -a /var/www/html/index.html",
    ]

    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = var.admin_password
      host        = azurerm_network_interface.backend[count.index].private_ip_address
      agent       = false
    }
  }

  depends_on = [
    azurerm_virtual_machine.backend
  ]
}
