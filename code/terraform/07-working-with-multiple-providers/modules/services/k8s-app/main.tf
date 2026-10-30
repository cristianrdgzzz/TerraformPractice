/*
 * Simple Kubernetes app module.
 *
 * This module intentionally sticks to first-party Kubernetes provider resources
 * so Chapter 7 can show how different providers (AWS for EKS, Kubernetes for
 * workloads) can be orchestrated from one Terraform root module. The deployment
 * and service wiring are minimal but production-ready patterns can extend from
 * here (e.g., add HPAs, ConfigMaps, TLS).
 */

terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

locals {
  pod_labels = {
    app = var.name
  }
}


# Metadata: Just as with the Deployment object, service object uses
#  metadata to identiy and target that object in API calls


# Create a simple Kubernetes Deployment to run an app
resource "kubernetes_deployment" "app" {
  metadata {
    name = var.name
  }

  spec {
    replicas = var.replicas

    template {
      metadata {
        labels = local.pod_labels
      }

      spec {
        container {
          name  = var.name
          image = var.image

          port {
            container_port = var.container_port
          }

          dynamic "env" {
            for_each = var.environment_variables
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }

    selector {
      match_labels = local.pod_labels
    }
  }
}

# Create a simple Kubernetes Service to spin up a load balancer in front
# of the app in the Kubernetes Deployment.
resource "kubernetes_service" "app" {
  metadata {
    name = var.name
  }

  spec {
    type = "LoadBalancer" # Elastic LB , Cloud LB, etc depending on cloud provider
    port {
      port        = 80 # Listening port on LB
      target_port = var.container_port
      protocol    = "TCP"
    }

    # Just as with the Deployment object, he Service object uses a selector to
    # specify what that Service should be targeting. By setting the selector to
    # pod_labels , the Service and the Deployment will both operate on
    # the same P

    selector = local.pod_labels
  }
}
