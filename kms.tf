resource "aws_kms_key" "main" {
  description = "Main KMS key for ${local.naming_prefix}"
  tags = merge(local.mandatory_tags, {
    Name = local.naming_prefix
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.naming_prefix}"
  target_key_id = aws_kms_key.main.key_id
}