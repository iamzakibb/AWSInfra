variable "required_tags" {
  type = map(string)
  default = {}
}


variable "bucket_names" {
  description = "List of S3 bucket names to create"
  type        = list(string)
}

variable "ec2_role_name" {
  description = "Name of the IAM role for EC2"
  type        = string
  default     = "s3_log_role"
}

variable "ec2_policy_name" {
  description = "Name of the IAM policy for S3 access"
  type        = string
  default     = "s3_log_policy"
}