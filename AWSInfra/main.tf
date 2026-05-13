resource "aws_s3_bucket" "log_bucket" {
  for_each = toset(var.bucket_names)

  bucket = each.value
}

resource "aws_s3_bucket_policy" "enforce_https" {
  for_each = aws_s3_bucket.log_bucket

  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_versioning" "versioning" {
  for_each = aws_s3_bucket.log_bucket

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "public_block" {
  for_each = aws_s3_bucket.log_bucket

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  for_each = aws_s3_bucket.log_bucket

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "s3_log_role" {
  name = var.ec2_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_log_policy" {
  name = var.ec2_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadWriteList"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = flatten([
          for b in aws_s3_bucket.log_bucket : [
            b.arn,
            "${b.arn}/*"
          ]
        ])
      },
      {
        Sid    = "DenyDeletes"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:DeleteObject",
          "s3:DeleteObjects",
          "s3:DeleteBucketPolicy"
        ]
        Resource = flatten([
          for b in aws_s3_bucket.log_bucket : [
            b.arn,
            "${b.arn}/*"
          ]
        ])
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.s3_log_role.name
  policy_arn = aws_iam_policy.s3_log_policy.arn
}