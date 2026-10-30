terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
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

# Define an Azure Resource Group
# Resource groups are containers that hold related resources for an Azure solution
resource "azurerm_resource_group" "db_server" {
  name     = var.resource_group_name
  location = var.location
}

# Define an Azure Database for MySQL Server
# This is a fully managed relational database service
# It provides automated backups, monitoring, and high availability
resource "azurerm_mysql_server" "db_server" {
  name                = var.db_server_name
  location            = azurerm_resource_group.db_server.location
  resource_group_name = azurerm_resource_group.db_server.name

  administrator_login          = var.db_admin_username
  administrator_login_password = var.db_admin_password

  sku_name   = var.db_sku_name
  storage_mb = var.db_storage_mb
  version    = var.db_version

  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = true
  public_network_access_enabled     = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
  ssl_enforcement_enabled           = true
}

# Define a MySQL Database within the server
# This is the actual database where data will be stored
resource "azurerm_mysql_database" "app_db" {
  name                = var.database_name
  resource_group_name = azurerm_resource_group.db_server.name
  server_name         = azurerm_mysql_server.db_server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

# Define firewall rules to allow specific IPs to connect to the database
# This controls which IP addresses can connect to your MySQL server
resource "azurerm_mysql_firewall_rule" "allow_azure_ips" {
  name                = "AllowAzureIPs"
  resource_group_name = azurerm_resource_group.db_server.name
  server_name         = azurerm_mysql_server.db_server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# Define a virtual network rule for private connectivity
# This allows resources within the same virtual network to access the database securely
resource "azurerm_mysql_virtual_network_rule" "app_network" {
  name                = "allow-app-vnet"
  resource_group_name = azurerm_resource_group.db_server.name
  server_name         = azurerm_mysql_server.db_server.name
  subnet_id           = var.app_subnet_id
}
