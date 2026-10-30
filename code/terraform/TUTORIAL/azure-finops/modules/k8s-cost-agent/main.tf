# ============================================================================
# Azure FinOps K8s Cost Agent Module - Main Configuration
# ============================================================================
# This module installs Kubecost or enables native Azure cost analysis for
# Azure Kubernetes Service (AKS) clusters, providing visibility into
# Kubernetes resource costs and allocation.
#
# Key Features:
# - Kubecost integration for detailed cost allocation
# - Native Azure cost analysis support
# - Pod-level cost visibility
# - Namespace and label-based cost attribution
# ============================================================================

# ----------------------------------------------------------------------------
# Kubecost Extension (Recommended)
# ----------------------------------------------------------------------------
# Kubecost provides the most detailed cost visibility for Kubernetes clusters,
# including pod-level costs, namespace allocation, and label-based attribution.
# ----------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_extension" "kubecost" {
  count = var.enable_kubecost ? 1 : 0

  name           = var.kubecost_extension_name
  cluster_id     = var.aks_cluster_id
  extension_type = "microsoft.azure.kubecost"
  release_train  = var.kubecost_release_train

  configuration_settings = var.kubecost_configuration_settings

  # Auto-upgrade settings
  auto_upgrade_minor_version = var.kubecost_auto_upgrade_minor_version

  tags = merge(
    var.tags,
    {
      Purpose     = "FinOps-K8sCostVisibility"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# Native Azure Cost Analysis (Alternative)
# ----------------------------------------------------------------------------
# Azure's native cost analysis provides basic cost visibility but is less
# detailed than Kubecost. It's included as an option for environments
# where Kubecost may not be suitable.
# ----------------------------------------------------------------------------
# Note: Native Azure cost analysis is typically enabled at the subscription
# level and doesn't require a specific resource. For AKS-specific cost
# visibility, Kubecost is recommended.
# ----------------------------------------------------------------------------
