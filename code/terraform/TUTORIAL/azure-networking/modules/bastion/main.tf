# ============================================================================
# Azure Bastion Module - Main Configuration
# ============================================================================
# Azure Bastion provides secure RDP/SSH access to VMs.
#
# Architecture:
# User Browser (HTTPS)
#     ↓
# Azure Portal / Bastion Service
#     ↓
# Azure Bastion Host (in AzureBastionSubnet)
#     ↓
# VM (Private IP, no public IP needed)
#
# Benefits:
# - No public IPs on VMs (reduces attack surface)
# - No VPN required (access from anywhere)
# - Browser-based (no client software)
# - All traffic encrypted (HTTPS)
# - NSG integration (uses NSG rules)
# ============================================================================

# ----------------------------------------------------------------------------
# Azure Bastion Host
# ----------------------------------------------------------------------------
# Azure Bastion is a fully managed PaaS service that provides:
# - Secure RDP/SSH access to VMs
# - Browser-based access (no client software)
# - No public IPs required on VMs
# - All traffic encrypted (HTTPS on port 443)
#
# Subnet Requirements:
# - Must be named 'AzureBastionSubnet'
# - Minimum /27 CIDR (32 IP addresses)
# - Recommended /26 CIDR (64 IP addresses)
# - Must be in the same VNet as the VMs you want to access
#
# SKU Options:
# - Basic: Standard features, 2 scale units
# - Standard: Advanced features (file copy, IP connect, tunneling), 2-50 scale units
#
# Features by SKU:
# - Basic: RDP/SSH, copy/paste
# - Standard: All Basic features + file copy, IP connect, shareable links, native client support
# ----------------------------------------------------------------------------
resource "azurerm_bastion_host" "main" {
  name                = var.bastion_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # IP Configuration: Defines the Bastion's subnet and public IP
  # The Bastion service uses this to provide connectivity
  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = var.public_ip_address_id
  }

  # SKU: Basic or Standard
  # Standard provides additional features like file copy and native client support
  sku = var.sku

  # Scale Units: Number of instances (only for Standard SKU)
  # More scale units = more concurrent connections
  # Default: 2, Range: 2-50
  scale_units = var.sku == "Standard" ? var.scale_units : null

  # Copy/Paste: Enable copy/paste between local machine and VM
  # Default: Enabled
  copy_paste_enabled = var.copy_paste_enabled

  # File Copy: Enable file transfer (only for Standard SKU)
  # Allows uploading/downloading files via browser
  file_copy_enabled = var.sku == "Standard" ? var.file_copy_enabled : null

  # IP Connect: Enable IP-based connection (only for Standard SKU)
  # Allows connecting to VMs using their private IP addresses
  ip_connect_enabled = var.sku == "Standard" ? var.ip_connect_enabled : null

  # Shareable Link: Enable shareable links (only for Standard SKU)
  # Allows creating time-limited shareable links for VM access
  shareable_link_enabled = var.sku == "Standard" ? var.shareable_link_enabled : null

  # Tunneling: Enable native client support (only for Standard SKU)
  # Allows using native RDP/SSH clients instead of browser
  tunneling_enabled = var.sku == "Standard" ? var.tunneling_enabled : null

  tags = var.tags
}

