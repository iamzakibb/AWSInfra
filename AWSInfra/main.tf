data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_root_arn    = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  default_kms_key_arn = coalesce(var.kms_key_arn, aws_kms_key.s3_bucket_kms_key.arn)

  common_tags = merge(
    var.common_tags,
    {
      AppServiceTag            = var.app_service_tag
      SecondLevelSupport       = var.second_level_support
      InformationClassification = var.information_classification
      ServiceOwner             = var.service_owner
      LineOfBusiness           = var.line_of_business
      Environment              = var.environment
      TenantName               = var.tenant_name
      PlatformName             = var.platform_name
      AWSRegion                = var.aws_region
    }
  )

  default_bucket_base = {
    force_destroy                            = var.force_destroy
    versioning_status                        = var.versioning_status
    acl_status                               = var.acl_status
    object_ownership                         = var.object_ownership
    block_public_access                      = var.block_public_access
    sse_algorithm                            = var.sse_algorithm
    kms_key_arn                              = local.default_kms_key_arn
    enable_bucket_key_encryption_local_cache = var.enable_bucket_key_encryption_local_cache
    create_lifecycle_config                  = var.create_lifecycle_config
    lifecycle_config_expiration_days         = var.lifecycle_config_expiration_days
  }

  merged_default_buckets = {
    for k, v in var.default_s3_buckets_custom_params_map :
    k => merge(local.default_bucket_base, v, {
      bucket_infx = k
      bucket_type  = "default"
    })
  }

  merged_adhoc_buckets = {
    for k, v in var.tenant_adhoc_s3_buckets_map :
    k => merge(local.default_bucket_base, v, {
      bucket_infx = k
      bucket_type  = "adhoc"
    })
  }

  all_buckets = merge(local.merged_default_buckets, local.merged_adhoc_buckets)

  acl_buckets = {
    for k, v in local.all_buckets :
    k => v
    if v.acl_status != null && upper(v.object_ownership) != "BUCKETOWNERENFORCED"
  }

  lifecycle_buckets = {
    for k, v in local.all_buckets :
    k => v
    if try(v.create_lifecycle_config, false)
  }

  kms_buckets = {
    for k, v in local.all_buckets :
    k => v
    if try(v.sse_algorithm, var.sse_algorithm) == "aws:kms"
  }
}

resource "aws_iam_role" "kms_s3_admin" {
  name = "${var.platform_name}-${var.tenant_name}-${var.environment}-kms-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.account_root_arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "s3_read_only" {
  name = "${var.platform_name}-${var.tenant_name}-${var.environment}-s3-read-only"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.account_root_arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "s3_read_write" {
  name = "${var.platform_name}-${var.tenant_name}-${var.environment}-s3-read-write"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.account_root_arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_kms_key" "s3_bucket_kms_key" {
  description         = "KMS key for encrypting ${var.tenant_name} S3 buckets"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "EnableRootPermissions"
          Effect    = "Allow"
          Principal = { AWS = local.account_root_arn }
          Action    = "kms:*"
          Resource  = "*"
        },
        {
          Sid       = "AllowKmsAdminRoleAccess"
          Effect    = "Allow"
          Principal = { AWS = aws_iam_role.kms_s3_admin.arn }
          Action = [
            "kms:Create*",
            "kms:Describe*",
            "kms:Enable*",
            "kms:List*",
            "kms:Put*",
            "kms:Update*",
            "kms:Revoke*",
            "kms:Disable*",
            "kms:Get*",
            "kms:Delete*",
            "kms:TagResource",
            "kms:UntagResource",
            "kms:ScheduleKeyDeletion",
            "kms:CancelKeyDeletion",
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*"
          ]
          Resource = "*"
        },
        {
          Sid       = "AllowReadOnlyRoleKmsUse"
          Effect    = "Allow"
          Principal = { AWS = aws_iam_role.s3_read_only.arn }
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey"
          ]
          Resource = "*"
        },
        {
          Sid       = "AllowReadWriteRoleKmsUse"
          Effect    = "Allow"
          Principal = { AWS = aws_iam_role.s3_read_write.arn }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ]
          Resource = "*"
        }
      ],
      var.enable_dms_s3_access && length(var.dms_role_arns) > 0 ? [
        {
          Sid       = "AllowDmsRoleArnsKmsUse"
          Effect    = "Allow"
          Principal = "*"
          Action = [
            "kms:Encrypt",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ]
          Resource = "*"
          Condition = {
            ArnLike = {
              "aws:PrincipalArn" = var.dms_role_arns
            }
          }
        }
      ] : []
    )
  })

  tags = local.common_tags
}

resource "aws_kms_alias" "s3_bucket_kms_key" {
  name          = "alias/${var.platform_name}-${var.tenant_name}-${var.environment}-s3"
  target_key_id = aws_kms_key.s3_bucket_kms_key.key_id
}

resource "aws_s3_bucket" "this" {
  for_each = local.all_buckets

  bucket        = replace(replace(replace(replace(replace(
    var.bucket_name_template,
    "{platform_name}", var.platform_name
  ), "{tenant_name}", var.tenant_name), "{bucket_infx}", each.value.bucket_infx), "{environment}", var.environment), "{aws_region}", var.aws_region)

  force_destroy = each.value.force_destroy

  tags = merge(
    local.common_tags,
    try(each.value.tags, {})
  )
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.all_buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = each.value.block_public_access
  block_public_policy     = each.value.block_public_access
  ignore_public_acls      = each.value.block_public_access
  restrict_public_buckets = each.value.block_public_access
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = local.all_buckets

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = each.value.versioning_status
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = local.all_buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    object_ownership = each.value.object_ownership
  }
}

resource "aws_s3_bucket_acl" "this" {
  for_each = local.acl_buckets

  bucket = aws_s3_bucket.this[each.key].id
  acl    = each.value.acl_status

  depends_on = [
    aws_s3_bucket_ownership_controls.this
  ]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.all_buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    bucket_key_enabled = try(each.value.enable_bucket_key_encryption_local_cache, var.enable_bucket_key_encryption_local_cache)

    apply_server_side_encryption_by_default {
      sse_algorithm     = try(each.value.sse_algorithm, var.sse_algorithm)
      kms_master_key_id = try(each.value.sse_algorithm, var.sse_algorithm) == "aws:kms" ? coalesce(try(each.value.kms_key_arn, null), local.default_kms_key_arn) : null
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.lifecycle_buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    id     = "${each.key}-expiration"
    status = "Enabled"

    filter {}

    expiration {
      days = each.value.lifecycle_config_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = each.value.lifecycle_config_expiration_days
    }
  }
}

resource "aws_iam_policy" "s3_read_only" {
  name = "${var.platform_name}-${var.tenant_name}-${var.environment}-s3-read-only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBucketReadMetadata"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          for b in aws_s3_bucket.this : b.arn
        ]
      },
      {
        Sid    = "AllowObjectRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          for b in aws_s3_bucket.this : "${b.arn}/*"
        ]
      },
      {
        Sid    = "AllowKmsDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.s3_bucket_kms_key.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "s3_read_only" {
  role       = aws_iam_role.s3_read_only.name
  policy_arn = aws_iam_policy.s3_read_only.arn
}

resource "aws_iam_policy" "s3_read_write" {
  name = "${var.platform_name}-${var.tenant_name}-${var.environment}-s3-read-write"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBucketReadMetadata"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          for b in aws_s3_bucket.this : b.arn
        ]
      },
      {
        Sid    = "AllowObjectReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          for b in aws_s3_bucket.this : "${b.arn}/*"
        ]
      },
      {
        Sid    = "AllowKmsReadWriteUse"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.s3_bucket_kms_key.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "s3_read_write" {
  role       = aws_iam_role.s3_read_write.name
  policy_arn = aws_iam_policy.s3_read_write.arn
}

resource "aws_s3_bucket_policy" "this" {
  for_each = local.all_buckets

  bucket = aws_s3_bucket.this[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "EnforceSecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource = [
            aws_s3_bucket.this[each.key].arn,
            "${aws_s3_bucket.this[each.key].arn}/*"
          ]
          Condition = {
            Bool = {
              "aws:SecureTransport" = "false"
            }
          }
        }
      ],
      [
        {
          Sid    = "AllowReadOnlyPrincipals"
          Effect = "Allow"
          Principal = {
            AWS = aws_iam_role.s3_read_only.arn
          }
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            aws_s3_bucket.this[each.key].arn,
            "${aws_s3_bucket.this[each.key].arn}/*"
          ]
        }
      ],
      [
        {
          Sid    = "AllowReadWritePrincipals"
          Effect = "Allow"
          Principal = {
            AWS = aws_iam_role.s3_read_write.arn
          }
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            aws_s3_bucket.this[each.key].arn,
            "${aws_s3_bucket.this[each.key].arn}/*"
          ]
        }
      ],
      var.enable_dms_s3_access && length(var.dms_role_arns) > 0 ? [
        {
          Sid    = "AllowDmsPrincipals"
          Effect = "Allow"
          Principal = {
            AWS = var.dms_role_arns
          }
          Action = [
            "s3:PutObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            aws_s3_bucket.this[each.key].arn,
            "${aws_s3_bucket.this[each.key].arn}/*"
          ]
        }
      ] : []
    )
  })
}
