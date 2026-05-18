output "bucket_names" {
  value = {
    for k, b in aws_s3_bucket.this : k => b.bucket
  }
}

output "bucket_arns" {
  value = {
    for k, b in aws_s3_bucket.this : k => b.arn
  }
}

output "kms_key_arn" {
  value = aws_kms_key.s3_bucket_kms_key.arn
}

output "kms_admin_role_arn" {
  value = aws_iam_role.kms_s3_admin.arn
}

output "s3_read_only_role_arn" {
  value = aws_iam_role.s3_read_only.arn
}

output "s3_read_write_role_arn" {
  value = aws_iam_role.s3_read_write.arn
}
