variable "resource_group_name" {
  description = "The name of the Azure Resource Group."
  type        = string
}

variable "location" {
  description = "The Azure region where the resources will be deployed."
  type        = string
  default     = "East US"
}

variable "vnet_name" {
  description = "The name of the virtual network."
  type        = string
}

variable "vnet_address_space" {
  description = "The address space for the virtual network (e.g., ['10.0.0.0/16'])."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "The name of the subnet."
  type        = string
}

variable "subnet_address_prefixes" {
  description = "The address prefixes for the subnet (e.g., ['10.0.1.0/24'])."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "nsg_name" {
  description = "The name of the Network Security Group."
  type        = string
}

variable "lb_name" {
  description = "The name of the load balancer."
  type        = string
}

variable "lb_pip_name" {
  description = "The name of the public IP for the load balancer."
  type        = string
}

variable "vmss_name" {
  description = "The name of the Virtual Machine Scale Set."
  type        = string
}

variable "vm_size" {
  description = "The size of the VMs in the scale set (e.g., 'Standard_B1s')."
  type        = string
  default     = "Standard_D2s_v7"
}

variable "instance_count" {
  description = "The initial number of instances in the scale set."
  type        = number
  default     = 2
}

variable "max_instance_count" {
  description = "The maximum number of instances that can be created by autoscaling."
  type        = number
  default     = 5
}
