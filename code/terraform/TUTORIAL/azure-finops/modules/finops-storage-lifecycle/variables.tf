# ============================================================================
# Azure FinOps Storage Lifecycle Module - Variables
# ============================================================================

variable "storage_account_id" {
  description = "The ID of the Storage Account to apply the lifecycle policy to. Can reference a storage account from a module output."
  type        = string
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules to apply to the storage account."
  type = list(object({
    name         = string
    enabled      = bool
    prefix_match = optional(list(string)) # Container prefixes to match (empty = all)
    blob_types   = optional(list(string)) # blob_types: ["blockBlob", "appendBlob"]
    base_blob = optional(object({
      tier_to_cool_after_days_since_modification_greater_than        = optional(number)
      tier_to_archive_after_days_since_modification_greater_than     = optional(number)
      delete_after_days_since_modification_greater_than              = optional(number)
      tier_to_cool_after_days_since_last_access_time_greater_than    = optional(number)
      tier_to_archive_after_days_since_last_access_time_greater_than = optional(number)
      delete_after_days_since_last_access_time_greater_than          = optional(number)
    }))
    snapshot = optional(object({
      delete_after_days_since_creation_greater_than          = optional(number)
      tier_to_cool_after_days_since_creation_greater_than    = optional(number)
      tier_to_archive_after_days_since_creation_greater_than = optional(number)
    }))
    version = optional(object({
      delete_after_days_since_creation_greater_than          = optional(number)
      tier_to_cool_after_days_since_creation_greater_than    = optional(number)
      tier_to_archive_after_days_since_creation_greater_than = optional(number)
    }))
  }))
  default = [
    {
      name         = "move-to-cool-and-archive"
      enabled      = true
      prefix_match = []
      blob_types   = ["blockBlob"]
      base_blob = {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }
    }
  ]
}

# Legacy variable for backward compatibility
variable "container_prefixes" {
  description = "[DEPRECATED] Use lifecycle_rules instead. List of container prefixes to apply the rules to. Leave empty for all."
  type        = list(string)
  default     = []
}
