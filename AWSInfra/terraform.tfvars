aws_region   = "us-west-1"
platform_name = "eds"
tenant_name   = "nit-eds-lobd1"
environment   = "pg"

app_service_tag             = "AppService1"
second_level_support        = "L1-SF ITS CASH"
information_classification  = "RESTRICTED FR"
service_owner               = "platform-name"
line_of_business            = "tenant-name"

default_s3_buckets_custom_params_map = {
  raw = {
    versioning_status                        = "Enabled"
    acl_status                               = "private"
    object_ownership                         = "BucketOwnerEnforced"
    block_public_access                      = true
    sse_algorithm                            = "aws:kms"
    enable_bucket_key_encryption_local_cache = true
    create_lifecycle_config                  = true
    lifecycle_config_expiration_days         = 365
    tags = {
      CostCenter = "CASH"
    }
  }
}

tenant_adhoc_s3_buckets_map = {
  adhoc1 = {
    versioning_status                        = "Enabled"
    acl_status                               = "private"
    object_ownership                         = "BucketOwnerEnforced"
    block_public_access                      = true
    sse_algorithm                            = "aws:kms"
    enable_bucket_key_encryption_local_cache = true
    create_lifecycle_config                  = false
  }
}

enable_dms_s3_access = false
