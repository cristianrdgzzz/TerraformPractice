# ============================================================================
# Azure DNS Module - Main Configuration
# ============================================================================
# Azure DNS provides DNS hosting for your domains with:
# - High availability (99.99% SLA)
# - Global distribution
# - Fast DNS resolution
# - Support for all standard DNS record types
# - Private DNS zones for internal name resolution
# ============================================================================

# ----------------------------------------------------------------------------
# Optional Resource Group Module
# ----------------------------------------------------------------------------
# This module can optionally create a resource group if create_resource_group
# is set to true. If false, it uses the provided resource_group_name variable.
# The try() function allows the module to work with or without the resource
# group module being instantiated.
# ----------------------------------------------------------------------------
module "resource_group" {
  source = "../resource-group"
  count  = var.create_resource_group ? 1 : 0

  project_name     = var.project_name
  application_name = var.application_name
  environment      = var.environment
  location         = var.location
  tags             = var.tags
}

# ----------------------------------------------------------------------------
# Local Values
# ----------------------------------------------------------------------------
# Determine the resource group name to use:
# - If resource group module is created, use its output
# - Otherwise, use the provided resource_group_name variable
# ----------------------------------------------------------------------------
locals {
  # Use the resource group name from the module if created, otherwise use the variable
  resource_group_name = try(module.resource_group[0].name, var.resource_group_name)
}

# ----------------------------------------------------------------------------
# Public DNS Zones
# ----------------------------------------------------------------------------
# Public DNS zones are used for internet-facing domains.
# They resolve DNS queries from anywhere on the Internet.
# 
# When a public DNS zone is created, Azure automatically:
# - Assigns 4 name servers from Azure's global DNS infrastructure
# - Creates an SOA (Start of Authority) record automatically
# - Creates NS (Name Server) records pointing to Azure name servers
# 
# The zone name must be unique within the resource group.
# ----------------------------------------------------------------------------
resource "azurerm_dns_zone" "public" {
  for_each = {
    # Filter DNS zones to only create public zones
    # Iterate through all zones and only process those with zone_type == "Public"
    for zone_name, zone_config in var.dns_zones : zone_name => zone_config
    if zone_config.zone_type == "Public"
  }

  # Zone name (e.g., "contoso.com")
  # This becomes the root domain for all records in this zone
  name = each.key

  # Resource group where the DNS zone will be created
  # Uses the local value that handles both module and variable scenarios
  resource_group_name = local.resource_group_name

  # Merge default tags with zone-specific tags
  # Zone-specific tags override default tags if there are conflicts
  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# Private DNS Zones
# ----------------------------------------------------------------------------
# Private DNS zones are used for internal name resolution within Azure
# Virtual Networks. They are not accessible from the Internet.
# 
# Key characteristics:
# - Globally scoped: accessible from any region, subscription, or VNet
# - Requires VNet links to enable name resolution
# - Supports automatic VM hostname registration
# - Can be shared across multiple virtual networks
# 
# When a private DNS zone is created, Azure automatically:
# - Creates an SOA (Start of Authority) record automatically
# - Replicates the zone across Azure regions for high availability
# ----------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "private" {
  for_each = {
    # Filter DNS zones to only create private zones
    # Iterate through all zones and only process those with zone_type == "Private"
    for zone_name, zone_config in var.dns_zones : zone_name => zone_config
    if zone_config.zone_type == "Private"
  }

  # Zone name (e.g., "internal.contoso.com")
  # This becomes the root domain for all records in this zone
  name = each.key

  # Resource group where the private DNS zone will be created
  # Uses the local value that handles both module and variable scenarios
  resource_group_name = local.resource_group_name

  # Merge default tags with zone-specific tags
  # Zone-specific tags override default tags if there are conflicts
  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# DNS Records (Public Zones)
# ----------------------------------------------------------------------------
# DNS records define how domain names resolve to IP addresses or other records.
# 
# Supported record types:
# - A: Maps a domain name to an IPv4 address (e.g., www.contoso.com -> 20.1.1.1)
# - AAAA: Maps a domain name to an IPv6 address
# - CNAME: Creates an alias from one domain name to another
# - MX: Specifies mail servers for the domain (includes priority)
# - NS: Specifies authoritative name servers (used for subdomain delegation)
# - PTR: Maps an IP address to a domain name (reverse DNS, requires reverse zone)
# - SRV: Specifies services available in the domain (includes priority, weight, port)
# - TXT: Stores text information (SPF, DKIM, DMARC, verification codes)
# - SOA: Start of Authority (automatically created by Azure, not user-configurable)
# 
# Note: SOA records are automatically created by Azure when a DNS zone is created.
# They contain authoritative information about the zone and cannot be manually
# created or modified through Terraform. The SOA record includes:
# - Primary name server
# - Responsible person email
# - Serial number (auto-incremented)
# - Refresh, retry, and expire intervals
# - Minimum TTL
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# A Records (IPv4 Address Mapping) - Public Zones
# ----------------------------------------------------------------------------
# A records map hostnames to IPv4 addresses.
# Multiple IP addresses can be specified for load balancing and redundancy.
# Example: www.contoso.com -> 20.1.1.1, 20.1.1.2
# ----------------------------------------------------------------------------
resource "azurerm_dns_a_record" "public" {
  for_each = {
    # Filter records to only process A records for public zones
    # Check that: record type is "A" AND the zone exists in public zones
    for key, record in var.dns_records : key => record
    if record.type == "A" && try(azurerm_dns_zone.public[record.zone_name], null) != null
  }

  # Record name (e.g., "www" for www.contoso.com, "@" for root domain)
  name = each.value.name

  # Zone name where this record will be created
  zone_name = azurerm_dns_zone.public[each.value.zone_name].name

  # Resource group containing the DNS zone
  resource_group_name = local.resource_group_name

  # Time To Live in seconds (how long DNS resolvers cache this record)
  # Common values: 300 (5 min) for dynamic, 3600 (1 hour) for static
  ttl = each.value.ttl

  # List of IPv4 addresses this record points to
  # Multiple addresses provide redundancy and load distribution
  records = each.value.records

  # Merge default tags with record-specific tags
  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# AAAA Records (IPv6 Address Mapping) - Public Zones
# ----------------------------------------------------------------------------
# AAAA records map hostnames to IPv6 addresses.
# Used for IPv6-enabled services and applications.
# Example: www.contoso.com -> 2001:0db8:85a3:0000:0000:8a2e:0370:7334
# ----------------------------------------------------------------------------
resource "azurerm_dns_aaaa_record" "public" {
  for_each = {
    # Filter records to only process AAAA records for public zones
    # Check that: record type is "AAAA" AND the zone exists in public zones
    for key, record in var.dns_records : key => record
    if record.type == "AAAA" && try(azurerm_dns_zone.public[record.zone_name], null) != null
  }

  # Record name (e.g., "www" for www.contoso.com)
  name = each.value.name

  # Zone name where this record will be created
  zone_name = azurerm_dns_zone.public[each.value.zone_name].name

  # Resource group containing the DNS zone
  resource_group_name = local.resource_group_name

  # Time To Live in seconds
  ttl = each.value.ttl

  # List of IPv6 addresses this record points to
  records = each.value.records

  # Merge default tags with record-specific tags
  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# CNAME Records (Canonical Name / Alias) - Public Zones
# ----------------------------------------------------------------------------
# CNAME records create an alias from one domain name to another.
# Important limitations:
# - Cannot create CNAME at root domain (@)
# - Cannot create other record types with the same name as a CNAME
# - CNAME must point to a fully qualified domain name (FQDN)
# Example: www-alias.contoso.com -> www.contoso.com
# ----------------------------------------------------------------------------
resource "azurerm_dns_cname_record" "public" {
  for_each = {
    # Filter records to only process CNAME records for public zones
    # Check that: record type is "CNAME" AND the zone exists in public zones
    for key, record in var.dns_records : key => record
    if record.type == "CNAME" && try(azurerm_dns_zone.public[record.zone_name], null) != null
  }

  # Record name (alias being created, e.g., "www-alias")
  name = each.value.name

  # Zone name where this record will be created
  zone_name = azurerm_dns_zone.public[each.value.zone_name].name

  # Resource group containing the DNS zone
  resource_group_name = local.resource_group_name

  # Time To Live in seconds
  ttl = each.value.ttl

  # CNAME can only have a single target (take first record from list)
  # The target must be a fully qualified domain name
  record = each.value.records[0]

  # Merge default tags with record-specific tags
  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# MX Records (Mail Exchange) - Public Zones
# ----------------------------------------------------------------------------
# MX records specify mail servers responsible for accepting email for the domain.
# Each MX record includes:
# - Preference (priority): Lower numbers have higher priority
# - Exchange: The mail server hostname
# 
# Input format in variables: "priority mailserver" (e.g., "10 mail.contoso.com")
# Multiple MX records allow mail server redundancy.
# Example: 
#   - "10 mail1.contoso.com" (primary)
#   - "20 mail2.contoso.com" (backup)
# ----------------------------------------------------------------------------
resource "azurerm_dns_mx_record" "public" {
  for_each = {
    # Filter records to only process MX records for public zones
    # Check that: record type is "MX" AND the zone exists in public zones
    for key, record in var.dns_records : key => record
    if record.type == "MX" && try(azurerm_dns_zone.public[record.zone_name], null) != null
  }

  # Record name (typically "@" for root domain)
  name = each.value.name

  # Zone name where this record will be created
  zone_name = azurerm_dns_zone.public[each.value.zone_name].name

  # Resource group containing the DNS zone
  resource_group_name = local.resource_group_name

  # Time To Live in seconds
  ttl = each.value.ttl

  # Dynamic block to create multiple MX records
  # Each record in the input list is parsed: "priority mailserver"
  # Split by space to extract preference (priority) and exchange (mailserver)
  dynamic "record" {
    for_each = each.value.records
    content {
      # Preference/priority: Lower number = higher priority
      # Mail servers are tried in order of preference
      preference = split(" ", record.value)[0]

      # Exchange: The mail server hostname (must be FQDN)
      exchange = split(" ", record.value)[1]
    }
  }

  # Merge default tags with record-specific tags
  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# TXT Records (Text Record) - Public Zones
# ----------------------------------------------------------------------------
# TXT records store text information, commonly used for:
# - SPF (Sender Policy Framework): Email authentication
# - DKIM (DomainKeys Identified Mail): Email signing
# - DMARC (Domain-based Message Authentication): Email policy
# - Domain verification codes (for various services)
# - Other arbitrary text data
# 
# Important: Azure TXT records use a "record" block with "value" attribute,
# not a direct "records" list. Each value can be up to 255 characters.
# Multiple values are concatenated automatically.
# 
# Example uses:
# - SPF: "v=spf1 include:spf.contoso.com -all"
# - Domain verification: "google-site-verification=abc123..."
# ----------------------------------------------------------------------------
resource "azurerm_dns_txt_record" "public" {
  for_each = {
    # Filter records to only process TXT records for public zones
    # Check that: record type is "TXT" AND the zone exists in public zones
    for key, record in var.dns_records : key => record
    if record.type == "TXT" && try(azurerm_dns_zone.public[record.zone_name], null) != null
  }

  # Record name (e.g., "@" for root, "_dmarc" for DMARC, etc.)
  name = each.value.name

  # Zone name where this record will be created
  zone_name = azurerm_dns_zone.public[each.value.zone_name].name

  # Resource group containing the DNS zone
  resource_group_name = local.resource_group_name

  # Time To Live in seconds
  ttl = each.value.ttl

  # TXT records require a "record" block with "value" attribute
  # Each string in the records list becomes a separate value in the TXT record
  # Azure automatically handles concatenation of multiple values
  dynamic "record" {
    for_each = each.value.records
    content {
      # Each value can be up to 255 characters
      # Multiple values are concatenated with spaces
      value = record.value
    }
  }

  # Merge default tags with record-specific tags
  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# Private DNS Records
# ----------------------------------------------------------------------------
# Private DNS zones support a subset of record types compared to public zones.
# Supported types: A, AAAA, CNAME, MX, PTR, SRV, TXT
# 
# Note: SOA and NS records are automatically created by Azure for private zones,
# similar to public zones. They cannot be manually configured.
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# A Records (IPv4 Address Mapping) - Private Zones
# ----------------------------------------------------------------------------
# Maps hostnames to IPv4 addresses within private DNS zones.
# Used for internal name resolution in virtual networks.
# Example: app1.internal.contoso.com -> 10.0.1.10
# ----------------------------------------------------------------------------
resource "azurerm_private_dns_a_record" "private" {
  for_each = {
    # Filter records to only process A records for private zones
    # Check that: record type is "A" AND the zone exists in private zones
    for key, record in var.dns_records : key => record
    if record.type == "A" && try(azurerm_private_dns_zone.private[record.zone_name], null) != null
  }

  # Record name (e.g., "app1" for app1.internal.contoso.com)
  name = each.value.name

  # Zone name where this record will be created
  zone_name = azurerm_private_dns_zone.private[each.value.zone_name].name

  # Resource group containing the private DNS zone
  resource_group_name = local.resource_group_name

  # Time To Live in seconds
  ttl = each.value.ttl

  # List of IPv4 addresses (typically private IPs like 10.x.x.x)
  records = each.value.records

  # Merge default tags with record-specific tags
  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# CNAME Records (Canonical Name / Alias) - Private Zones
# ----------------------------------------------------------------------------
# Creates aliases within private DNS zones.
# Same limitations as public CNAME records apply.
# Example: api.internal.contoso.com -> api-backend.internal.contoso.com
# ----------------------------------------------------------------------------
resource "azurerm_private_dns_cname_record" "private" {
  for_each = {
    # Filter records to only process CNAME records for private zones
    # Check that: record type is "CNAME" AND the zone exists in private zones
    for key, record in var.dns_records : key => record
    if record.type == "CNAME" && try(azurerm_private_dns_zone.private[record.zone_name], null) != null
  }

  # Record name (alias being created)
  name = each.value.name

  # Zone name where this record will be created
  zone_name = azurerm_private_dns_zone.private[each.value.zone_name].name

  # Resource group containing the private DNS zone
  resource_group_name = local.resource_group_name

  # Time To Live in seconds
  ttl = each.value.ttl

  # CNAME target (single record, must be FQDN)
  record = each.value.records[0]

  # Merge default tags with record-specific tags
  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# Private DNS Zone Virtual Network Links
# ----------------------------------------------------------------------------
# Virtual network links connect private DNS zones to Virtual Networks,
# enabling name resolution for resources in those networks.
# 
# Key features:
# - One private DNS zone can link to multiple virtual networks
# - Each link can have different registration settings
# - When registration_enabled = true: VMs automatically register hostnames
# - When registration_enabled = false: All records must be created manually
# 
# Auto-registration behavior:
# - VMs in linked VNets automatically create A records with their hostname
# - Records are created when VM starts and removed when VM is deleted
# - Only works for VMs in the same subscription and region
# - Hostname format: {vm-name}.{private-dns-zone-name}
# 
# Cross-VNet resolution:
# - VMs in any linked VNet can resolve names from all linked VNets
# - Enables service discovery across multiple virtual networks
# ----------------------------------------------------------------------------
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  for_each = var.private_dns_zone_virtual_network_links

  # Link name: Extract from the key (format: "zone_name/vnet_link_name")
  # The key format allows multiple links per zone with unique names
  name = split("/", each.key)[1]

  # Resource group containing the private DNS zone
  resource_group_name = local.resource_group_name

  # Name of the private DNS zone to link
  private_dns_zone_name = each.value.zone_name

  # ID of the virtual network to link
  # This enables the VNet to resolve names in the private DNS zone
  virtual_network_id = each.value.virtual_network_id

  # Auto-registration setting:
  # - true: VMs in this VNet automatically register their hostnames
  # - false: All DNS records must be created manually
  registration_enabled = each.value.registration_enabled

  # Merge default tags with link-specific tags
  tags = merge(var.tags, each.value.tags)
}

