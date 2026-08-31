locals {
  create         = var.audit_log_enabled && var.cloudwatch_audit_log_enabled
  log_group_name = var.log_group_name != "" ? var.log_group_name : "/hcp/vault/${var.cluster_id}/audit"
  iam_user_name  = "hcp-vault-${var.cluster_id}-audit"
}

# Destination for the audit stream.
resource "aws_cloudwatch_log_group" "this" {
  count = local.create ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.retention_in_days
  tags              = var.tags
}

# HCP Vault authenticates to CloudWatch with a static access key - there is no
# role-ARN option in the audit_log_config schema. Dedicated user, least priv.
resource "aws_iam_user" "this" {
  count = local.create ? 1 : 0

  name = local.iam_user_name
  tags = var.tags
}

resource "aws_iam_access_key" "this" {
  count = local.create ? 1 : 0

  user = aws_iam_user.this[0].name
}

resource "aws_iam_user_policy" "this" {
  count = local.create ? 1 : 0

  name = "hcp-vault-audit-cloudwatch"
  user = aws_iam_user.this[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeLogGroups"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Sid    = "WriteAuditStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = [
          aws_cloudwatch_log_group.this[0].arn,
          "${trimsuffix(aws_cloudwatch_log_group.this[0].arn, ":*")}:log-stream:*",
        ]
      },
    ]
  })
}

locals {
  # Sparse audit_log_config payload - vault-cluster reads every field through
  # try(), so only the cloudwatch_* keys need to be present.
  config = local.create ? [{
    cloudwatch_region            = var.aws_region
    cloudwatch_group_name        = local.log_group_name
    cloudwatch_access_key_id     = aws_iam_access_key.this[0].id
    cloudwatch_secret_access_key = aws_iam_access_key.this[0].secret
  }] : []
}
