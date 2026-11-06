
# ---------------------------------------------------------------------------
# Module inputs (variables)
#
# This file defines the variables that must be provided by the caller of the
# module and the optional parameters with sensible defaults. Each variable
# includes a description, type, and when appropriate a default value.
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name to use for all the cluster resources (used as a prefix)."
  type        = string
}

variable "db_remote_state_bucket" {
  description = "S3 bucket name where the remote state for the database stack is stored."
  type        = string
}

variable "db_remote_state_key" {
  description = "S3 key (path) for the database stack remote state file. Example: 'envs/prod/db/terraform.tfstate'"
  type        = string
}

# -------------------------------- CONFIGURATION PARAMETERS --------------------------------

variable "instance_type" {
  description = "The EC2 instance type to run for web servers (e.g. t3.micro). Choose an instance suitable for your load."
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group. Set to 0 to allow no instances during low load."
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group. Controls cost and capacity limits."
  type        = number
}

# Optional parameters
variable "server_port" {
  description = "Port the application listens on inside the instance. The ALB forwards traffic to this port via the target group."
  type        = number
  default     = 8080
}

# Notes:
# - This example uses the default VPC and default subnets discovered via
#   data sources in `main.tf`. For production, pass network ids as inputs.
# - The remote state configuration (S3 bucket/key) is intentionally left as
#   inputs so you can reuse the module across environments (prod/stage).

