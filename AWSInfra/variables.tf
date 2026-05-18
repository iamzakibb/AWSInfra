variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "platform_name" {
  description = "Platform / landing zone name used in bucket naming"
  type        = string
}

variable "tenant_name" {
  description = "Tenant name used in bucket naming"
  type        = string
}

variable "environment" {
  description = "Environment name used in bucket naming"
  type        = string
}

variable "bucket_name_template" {
  description = "Template for S3 bucket names. Supported placeholders: {platform_name}, {tenant_name}, {bucket_infx}, {environment}, {aws_region}"
  type        = string
  default     = "{platform_name}-{tenant_name}-{bucket_infx}-{environment}-{aws_region}"
}

variable "app_service_tag" {
  type        = string
  description = "AppServiceTag value from the docs"
  default     = ""
}

variable "second_level_support" {
  type        = string
  description = "2nd level support tag"
  default     = ""
}

variable "information_classification" {
  type        = string
  description = "Information classification tag"
  default     = ""
}

variable "service_owner" {
  type        = string
  description = "Service owner tag"
  default     = ""
}

variable "line_of_business" {
  type        = string
  description = "Line of business tag"
  default     = ""
}

variable "common_tags" {
  description = "Additional common tags"
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Default force destroy for buckets"
  type        = bool
  default     = false
}

variable "versioning_status" {
  description = "Default versioning status"
  type        = string
  default     = "Enabled"
}

variable "acl_status" {
  description = "Default ACL status if ACLs are allowed"
  type        = string
  default     = "private"
}

variable "object_ownership" {
  description = "Default object ownership"
  type        = string
  default     = "BucketOwnerEnforced"
}

variable "block_public_access" {
  description = "Default public access block"
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Default SSE algorithm. Docs indicate aws:kms"
  type        = string
  default     = "aws:kms"
}

variable "kms_key_arn" {
  description = "Optional KMS CMK ARN override for S3 encryption. Leave unset to use the KMS key created by this module."
  type        = string
  default     = null
}

variable "enable_bucket_key_encryption_local_cache" {
  description = "Enable S3 bucket key local cache"
  type        = bool
  default     = true
}

variable "create_lifecycle_config" {
  description = "Enable lifecycle configuration"
  type        = bool
  default     = false
}

variable "lifecycle_config_expiration_days" {
  description = "Expiration days for lifecycle config"
  type        = number
  default     = 365
}

variable "default_s3_buckets_custom_params_map" {
  description = "Default S3 buckets map from the docs"
  type = map(object({
    force_destroy                            = optional(bool)
    versioning_status                        = optional(string)
    acl_status                               = optional(string)
    object_ownership                         = optional(string)
    block_public_access                      = optional(bool)
    sse_algorithm                            = optional(string)
    kms_key_arn                              = optional(string)
    enable_bucket_key_encryption_local_cache = optional(bool)
    create_lifecycle_config                  = optional(bool)
    lifecycle_config_expiration_days         = optional(number)
    tags                                     = optional(map(string))
  }))
  default = {}
}

variable "tenant_adhoc_s3_buckets_map" {
  description = "Adhoc S3 buckets map from the docs"
  type = map(object({
    force_destroy                            = optional(bool)
    versioning_status                        = optional(string)
    acl_status                               = optional(string)
    object_ownership                         = optional(string)
    block_public_access                      = optional(bool)
    sse_algorithm                            = optional(string)
    kms_key_arn                              = optional(string)
    enable_bucket_key_encryption_local_cache = optional(bool)
    create_lifecycle_config                  = optional(bool)
    lifecycle_config_expiration_days         = optional(number)
    tags                                     = optional(map(string))
  }))
  default = {}
}

variable "dms_role_arns" {
  description = "Existing DMS role ARNs if DMS access is enabled"
  type        = list(string)
  default     = []
}

variable "enable_dms_s3_access" {
  description = "Enable DMS-specific S3 access policy statements"
  type        = bool
  default     = false
}
