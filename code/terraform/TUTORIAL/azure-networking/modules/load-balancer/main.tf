# ============================================================================
# Azure Load Balancer Module - Main Configuration
# ============================================================================
# This module creates an Azure Load Balancer with:
# - Frontend IP configurations (public or private)
# - Backend address pools
# - Health probes
# - Load balancing rules
# - Outbound rules (for outbound NAT)
# - Inbound NAT rules (for port forwarding)
#
# Architecture:
# Internet/Client
#     ↓
# Frontend IP (Public/Private)
#     ↓
# Load Balancing Rule
#     ↓
# Health Probe (checks backend health)
#     ↓
# Backend Pool (VMs/Scale Sets)
# ============================================================================

# ----------------------------------------------------------------------------
# Load Balancer
# ----------------------------------------------------------------------------
# The Load Balancer distributes incoming traffic across healthy backend instances.
# 
# SKU Options:
# - Basic: Free, limited features, no SLA
# - Standard: Paid, full features, 99.99% SLA, zone-redundant support
#
# Key Features:
# - Layer 4 (TCP/UDP) load balancing
# - Health probes to detect unhealthy backends
# - Automatic failover
# - Outbound connectivity for backend VMs
# ----------------------------------------------------------------------------
resource "azurerm_lb" "main" {
  name                = var.load_balancer_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  sku_tier            = var.sku_tier

  # Frontend IP configurations define where traffic enters the load balancer
  # Can be public (internet-facing) or private (internal)
  dynamic "frontend_ip_configuration" {
    for_each = var.frontend_ip_configurations
    content {
      name                          = frontend_ip_configuration.value.name
      public_ip_address_id          = frontend_ip_configuration.value.public_ip_address_id
      private_ip_address            = frontend_ip_configuration.value.private_ip_address
      private_ip_address_allocation = frontend_ip_configuration.value.private_ip_address_allocation
      subnet_id                     = frontend_ip_configuration.value.subnet_id
      zones                         = frontend_ip_configuration.value.zones
    }
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Backend Address Pools
# ----------------------------------------------------------------------------
# Backend pools contain the resources that receive traffic:
# - Virtual machines (via network interfaces)
# - Virtual machine scale sets
# - IP addresses (for IP-based backends)
#
# Traffic is distributed across healthy instances in the pool using:
# - Round-robin (default)
# - Source IP affinity (sticky sessions)
# ----------------------------------------------------------------------------
resource "azurerm_lb_backend_address_pool" "main" {
  for_each = {
    for pool in var.backend_address_pools : pool.name => pool
  }

  name            = each.value.name
  loadbalancer_id = azurerm_lb.main.id
}

# ----------------------------------------------------------------------------
# Health Probes
# ----------------------------------------------------------------------------
# Health probes check the health of backend resources:
# - HTTP/HTTPS: Checks HTTP status code (200-399 = healthy)
# - TCP: Checks if TCP connection can be established
#
# Unhealthy instances are removed from the pool until they become healthy.
# This ensures traffic only goes to healthy backends.
# ----------------------------------------------------------------------------
resource "azurerm_lb_probe" "main" {
  for_each = {
    for probe in var.probe_configurations : probe.name => probe
  }

  name                = each.value.name
  loadbalancer_id     = azurerm_lb.main.id
  protocol            = each.value.protocol
  port                = each.value.port
  request_path        = each.value.request_path
  interval_in_seconds = each.value.interval_in_seconds
  number_of_probes    = each.value.number_of_probes
}

# ----------------------------------------------------------------------------
# Load Balancing Rules
# ----------------------------------------------------------------------------
# Load balancing rules define how traffic is distributed:
# - Frontend IP: Where traffic enters
# - Backend pool: Where traffic goes
# - Probe: Health check to use
# - Protocol/Ports: TCP/UDP and port mapping
#
# Traffic Distribution:
# - Round-robin: Distributes evenly (default)
# - Source IP affinity: Same client → same backend (sticky sessions)
#
# Floating IP:
# - Required for SQL Always On Availability Groups
# - Allows the same IP to be used on multiple VMs
# ----------------------------------------------------------------------------
resource "azurerm_lb_rule" "main" {
  for_each = {
    for rule in var.load_balancing_rules : rule.name => rule
  }

  name                           = each.value.name
  loadbalancer_id                = azurerm_lb.main.id
  frontend_ip_configuration_name = each.value.frontend_ip_configuration_name
  backend_address_pool_ids       = each.value.backend_address_pool_ids
  probe_id                       = each.value.probe_id
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  enable_floating_ip             = each.value.enable_floating_ip
  enable_tcp_reset               = each.value.enable_tcp_reset
  disable_outbound_snat          = each.value.disable_outbound_snat
}

# ----------------------------------------------------------------------------
# Outbound Rules
# ----------------------------------------------------------------------------
# Outbound rules provide outbound NAT for backend resources:
# - Allows VMs without public IPs to access the internet
# - Uses the load balancer's frontend IP as the source
# - Provides SNAT (Source Network Address Translation)
#
# Use Cases:
# - Backend VMs need to download updates
# - Backend VMs need to call external APIs
# - Backend VMs need to access Azure services
#
# Port Allocation:
# - Default: 1024 ports per VM
# - Can be configured per rule
# - More ports = more concurrent connections
# ----------------------------------------------------------------------------
resource "azurerm_lb_outbound_rule" "main" {
  for_each = {
    for rule in var.outbound_rules : rule.name => rule
  }

  name            = each.value.name
  loadbalancer_id = azurerm_lb.main.id
  frontend_ip_configuration {
    name = each.value.frontend_ip_configuration_name
  }
  backend_address_pool_id  = each.value.backend_address_pool_id
  protocol                 = each.value.protocol
  allocated_outbound_ports = each.value.allocated_outbound_ports
  idle_timeout_in_minutes  = each.value.idle_timeout_in_minutes
  enable_tcp_reset         = each.value.enable_tcp_reset
}

# ----------------------------------------------------------------------------
# Inbound NAT Rules
# ----------------------------------------------------------------------------
# Inbound NAT rules provide direct access to specific VMs:
# - Port forwarding: External port → VM port
# - Useful for RDP/SSH access to specific backend VMs
# - Each rule maps to a specific VM (not load balanced)
#
# Example:
# - Frontend port 50001 → Backend VM1 port 3389 (RDP)
# - Frontend port 50002 → Backend VM2 port 3389 (RDP)
#
# Note: For load-balanced access, use load balancing rules instead.
# ----------------------------------------------------------------------------
resource "azurerm_lb_nat_rule" "main" {
  for_each = {
    for rule in var.inbound_nat_rules : rule.name => rule
  }

  name                           = each.value.name
  loadbalancer_id                = azurerm_lb.main.id
  frontend_ip_configuration_name = each.value.frontend_ip_configuration_name
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  enable_floating_ip             = each.value.enable_floating_ip
  enable_tcp_reset               = each.value.enable_tcp_reset
}

