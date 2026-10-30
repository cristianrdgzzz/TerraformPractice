# ============================================================================
# Azure Load Balancer Module - Variables
# ============================================================================
# This module creates an Azure Load Balancer (Standard SKU) that distributes
# incoming and outgoing traffic across multiple backend resources.
#
# Load Balancers provide:
# - High availability by distributing traffic
# - Health probes to detect unhealthy backends
# - Load balancing rules for inbound traffic
# - Outbound rules for outbound traffic (NAT)
# - Support for both public and internal load balancers
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group where the Load Balancer will be created"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "load_balancer_name" {
  description = "Name of the Load Balancer"
  type        = string
}

variable "sku" {
  description = "SKU of the Load Balancer. Options: 'Basic' or 'Standard'. Standard is recommended for production."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard"], var.sku)
    error_message = "SKU must be either 'Basic' or 'Standard'."
  }
}

variable "sku_tier" {
  description = "SKU tier. Options: 'Regional' or 'Global'. Global is only available for Standard SKU."
  type        = string
  default     = "Regional"

  validation {
    condition     = contains(["Regional", "Global"], var.sku_tier)
    error_message = "SKU tier must be either 'Regional' or 'Global'."
  }
}

variable "frontend_ip_configurations" {
  description = <<-EOT
    List of frontend IP configurations.
    Each frontend IP can be:
    - Public: Uses a public IP address (for internet-facing load balancers)
    - Private: Uses a private IP from a subnet (for internal load balancers)
    
    Example:
    frontend_ip_configurations = [
      {
        name                          = "public-frontend"
        public_ip_address_id          = azurerm_public_ip.lb.id
        private_ip_address            = null
        private_ip_address_allocation = null
        subnet_id                     = null
        zones                         = ["1", "2", "3"]
      },
      {
        name                          = "private-frontend"
        public_ip_address_id          = null
        private_ip_address            = "10.0.1.100"
        private_ip_address_allocation = "Static"
        subnet_id                     = azurerm_subnet.internal.id
        zones                         = null
      }
    ]
  EOT
  type = list(object({
    name                          = string
    public_ip_address_id          = optional(string, null)
    private_ip_address            = optional(string, null)
    private_ip_address_allocation = optional(string, null) # "Static" or "Dynamic"
    subnet_id                     = optional(string, null)
    zones                         = optional(list(string), null)
  }))
}

variable "backend_address_pools" {
  description = <<-EOT
    List of backend address pools.
    Backend pools contain the resources that will receive traffic.
    Resources can be:
    - Virtual machines (via network interface)
    - Virtual machine scale sets
    - IP addresses
    
    Example:
    backend_address_pools = [
      {
        name = "web-backend-pool"
      }
    ]
  EOT
  type = list(object({
    name = string
  }))

  default = []
}

variable "probe_configurations" {
  description = <<-EOT
    List of health probe configurations.
    Health probes check the health of backend resources.
    Unhealthy resources are removed from the pool until they become healthy again.
    
    Probe types:
    - HTTP: Checks HTTP endpoint (e.g., /health)
    - HTTPS: Checks HTTPS endpoint
    - TCP: Checks TCP connection
    
    Example:
    probe_configurations = [
      {
        name                = "http-probe"
        protocol            = "Http"
        port                = 80
        request_path        = "/health"
        interval_in_seconds = 5
        number_of_probes    = 2
      }
    ]
  EOT
  type = list(object({
    name                = string
    protocol            = string # "Http", "Https", or "Tcp"
    port                = number
    request_path        = optional(string, null) # Required for Http/Https
    interval_in_seconds = optional(number, 15)
    number_of_probes    = optional(number, 2)
  }))

  default = []
}

variable "load_balancing_rules" {
  description = <<-EOT
    List of load balancing rules.
    Load balancing rules define how traffic is distributed to backend pools.
    
    Example:
    load_balancing_rules = [
      {
        name                           = "http-rule"
        frontend_ip_configuration_name = "public-frontend"
        backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
        probe_id                       = azurerm_lb_probe.http.id
        protocol                       = "Tcp"
        frontend_port                  = 80
        backend_port                   = 80
        idle_timeout_in_minutes        = 4
        enable_floating_ip             = false
        enable_tcp_reset               = true
        disable_outbound_snat          = false
      }
    ]
  EOT
  type = list(object({
    name                           = string
    frontend_ip_configuration_name = string
    backend_address_pool_ids       = list(string)
    probe_id                       = optional(string, null)
    protocol                       = string # "Tcp" or "Udp"
    frontend_port                  = number
    backend_port                   = number
    idle_timeout_in_minutes        = optional(number, 4)
    enable_floating_ip             = optional(bool, false) # Required for SQL Always On
    enable_tcp_reset               = optional(bool, false)
    disable_outbound_snat          = optional(bool, false) # Use outbound rules instead
  }))

  default = []
}

variable "outbound_rules" {
  description = <<-EOT
    List of outbound rules.
    Outbound rules provide outbound NAT (Network Address Translation) for backend resources.
    This allows VMs without public IPs to access the internet.
    
    Example:
    outbound_rules = [
      {
        name                        = "outbound-rule"
        frontend_ip_configuration_name = "public-frontend"
        backend_address_pool_id     = azurerm_lb_backend_address_pool.web.id
        protocol                    = "All" # "Tcp", "Udp", or "All"
        allocated_outbound_ports    = 1024
        idle_timeout_in_minutes     = 4
        enable_tcp_reset            = true
      }
    ]
  EOT
  type = list(object({
    name                           = string
    frontend_ip_configuration_name = string
    backend_address_pool_id        = string
    protocol                       = string # "Tcp", "Udp", or "All"
    allocated_outbound_ports       = number # Number of ports per VM (default: 1024)
    idle_timeout_in_minutes        = optional(number, 4)
    enable_tcp_reset               = optional(bool, false)
  }))

  default = []
}

variable "inbound_nat_rules" {
  description = <<-EOT
    List of inbound NAT rules.
    Inbound NAT rules provide direct access to specific VMs (port forwarding).
    Useful for RDP/SSH access to specific backend VMs.
    
    Example:
    inbound_nat_rules = [
      {
        name                           = "rdp-vm1"
        frontend_ip_configuration_name = "public-frontend"
        protocol                       = "Tcp"
        frontend_port                  = 50001
        backend_port                   = 3389
        idle_timeout_in_minutes        = 4
        enable_floating_ip             = false
        enable_tcp_reset               = false
      }
    ]
  EOT
  type = list(object({
    name                           = string
    frontend_ip_configuration_name = string
    protocol                       = string # "Tcp" or "Udp"
    frontend_port                  = number
    backend_port                   = number
    idle_timeout_in_minutes        = optional(number, 4)
    enable_floating_ip             = optional(bool, false)
    enable_tcp_reset               = optional(bool, false)
  }))

  default = []
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

