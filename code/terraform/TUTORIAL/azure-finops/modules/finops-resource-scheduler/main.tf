# ============================================================================
# Azure FinOps Resource Scheduler Module - Main Configuration
# ============================================================================
# This module creates Automation Accounts and Runbooks to automatically
# start/stop Azure resources (VMs, etc.) based on schedules, optimizing costs
# for non-production environments.
#
# Key Features:
# - Automated VM shutdown/startup based on schedules
# - Tag-based resource selection
# - Multiple schedule configurations
# - Support for existing Automation Accounts from modules
# ============================================================================

# ----------------------------------------------------------------------------
# Automation Account Configuration
# ----------------------------------------------------------------------------
# OPTION 1: Create a new Automation Account (default behavior)
# This is useful for standalone deployments or team-specific automation.
# ----------------------------------------------------------------------------
resource "azurerm_automation_account" "scheduler" {
  count = var.create_automation_account ? 1 : 0

  name                          = var.automation_account_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = var.automation_account_sku
  public_network_access_enabled = var.automation_public_network_access

  identity {
    type = var.automation_identity_type
  }

  tags = merge(
    var.tags,
    {
      Purpose     = "FinOps-ResourceScheduler"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# OPTION 2: Reference an existing Automation Account via data source
# ----------------------------------------------------------------------------
# If you have a centralized automation account managed by a shared-services module,
# use this data source instead of creating a new one:
#
# data "azurerm_automation_account" "existing" {
#   name                = var.existing_automation_account_name
#   resource_group_name = var.existing_automation_account_resource_group_name
# }
#
# Then reference it in runbooks and schedules:
# automation_account_name = var.create_automation_account ? azurerm_automation_account.scheduler[0].name : data.azurerm_automation_account.existing[0].name
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# OPTION 3: Reference an Automation Account created by a module
# ----------------------------------------------------------------------------
# If you're using a centralized automation_account module (e.g., from a shared
# infrastructure repository), you can pass the automation account name/resource group:
#
# module "shared_automation" {
#   source = "git::https://github.com/org/terraform-azurerm-automation-account.git"
#   # ... automation account configuration
# }
#
# module "resource_scheduler" {
#   source = "./modules/finops-resource-scheduler"
#   # ... other variables
#   create_automation_account = false
#   existing_automation_account_name = module.shared_automation.automation_account_name
#   existing_automation_account_resource_group_name = module.shared_automation.resource_group_name
# }
#
# This approach is recommended for enterprise environments where automation
# accounts are managed centrally for compliance, security, and cost optimization.
# ----------------------------------------------------------------------------

# Local values for automation account
locals {
  automation_account_name                = var.create_automation_account ? azurerm_automation_account.scheduler[0].name : var.existing_automation_account_name
  automation_account_resource_group_name = var.create_automation_account ? var.resource_group_name : var.existing_automation_account_resource_group_name
}

# ----------------------------------------------------------------------------
# Automation Runbooks
# ----------------------------------------------------------------------------
resource "azurerm_automation_runbook" "stop_vm" {
  name                    = var.stop_runbook_name
  location                = var.location
  resource_group_name     = local.automation_account_resource_group_name
  automation_account_name = local.automation_account_name
  log_verbose             = var.runbook_log_verbose
  log_progress            = var.runbook_log_progress
  description             = var.stop_runbook_description
  runbook_type            = var.runbook_type

  content = var.stop_runbook_content != null ? var.stop_runbook_content : <<POWERSHELL
Param(
    [string]$TagName = "${var.schedule_tag_name}",
    [string]$TagValue = "${var.schedule_tag_value}"
)

# Authenticate to Azure
$connection = Get-AutomationConnection -Name "AzureRunAsConnection"
Connect-AzAccount -ServicePrincipal -TenantId $connection.TenantId `
    -ApplicationId $connection.ApplicationId -CertificateThumbprint $connection.CertificateThumbprint

$vms = Get-AzVM -Status | Where-Object { $_.Tags[$TagName] -eq $TagValue -and $_.PowerState -eq "VM running" }

foreach ($vm in $vms) {
    Write-Output "Stopping VM: $($vm.Name)"
    Stop-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force -NoWait
}
POWERSHELL
}

resource "azurerm_automation_runbook" "start_vm" {
  count = var.create_start_runbook ? 1 : 0

  name                    = var.start_runbook_name
  location                = var.location
  resource_group_name     = local.automation_account_resource_group_name
  automation_account_name = local.automation_account_name
  log_verbose             = var.runbook_log_verbose
  log_progress            = var.runbook_log_progress
  description             = var.start_runbook_description
  runbook_type            = var.runbook_type

  content = var.start_runbook_content != null ? var.start_runbook_content : <<POWERSHELL
Param(
    [string]$TagName = "${var.schedule_tag_name}",
    [string]$TagValue = "${var.schedule_tag_value}"
)

# Authenticate to Azure
$connection = Get-AutomationConnection -Name "AzureRunAsConnection"
Connect-AzAccount -ServicePrincipal -TenantId $connection.TenantId `
    -ApplicationId $connection.ApplicationId -CertificateThumbprint $connection.CertificateThumbprint

$vms = Get-AzVM -Status | Where-Object { $_.Tags[$TagName] -eq $TagValue -and $_.PowerState -eq "VM deallocated" }

foreach ($vm in $vms) {
    Write-Output "Starting VM: $($vm.Name)"
    Start-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -NoWait
}
POWERSHELL
}

# ----------------------------------------------------------------------------
# Automation Schedules
# ----------------------------------------------------------------------------
resource "azurerm_automation_schedule" "stop_schedule" {
  name                    = var.stop_schedule_name
  resource_group_name     = local.automation_account_resource_group_name
  automation_account_name = local.automation_account_name
  frequency               = var.stop_schedule_frequency
  interval                = var.stop_schedule_interval
  start_time              = var.stop_schedule_start_time != null ? var.stop_schedule_start_time : "${formatdate("YYYY-MM-DD", timestamp())}T${var.stop_schedule_time}+00:00"
  timezone                = var.schedule_timezone
  description             = var.stop_schedule_description
}

resource "azurerm_automation_schedule" "start_schedule" {
  count = var.create_start_runbook ? 1 : 0

  name                    = var.start_schedule_name
  resource_group_name     = local.automation_account_resource_group_name
  automation_account_name = local.automation_account_name
  frequency               = var.start_schedule_frequency
  interval                = var.start_schedule_interval
  start_time              = var.start_schedule_start_time != null ? var.start_schedule_start_time : "${formatdate("YYYY-MM-DD", timestamp())}T${var.start_schedule_time}+00:00"
  timezone                = var.schedule_timezone
  description             = var.start_schedule_description
}

# ----------------------------------------------------------------------------
# Job Schedules (Link Runbooks to Schedules)
# ----------------------------------------------------------------------------
resource "azurerm_automation_job_schedule" "stop_job" {
  resource_group_name     = local.automation_account_resource_group_name
  automation_account_name = local.automation_account_name
  schedule_name           = azurerm_automation_schedule.stop_schedule.name
  runbook_name            = azurerm_automation_runbook.stop_vm.name
}

resource "azurerm_automation_job_schedule" "start_job" {
  count = var.create_start_runbook ? 1 : 0

  resource_group_name     = local.automation_account_resource_group_name
  automation_account_name = local.automation_account_name
  schedule_name           = azurerm_automation_schedule.start_schedule[0].name
  runbook_name            = azurerm_automation_runbook.start_vm[0].name
}
