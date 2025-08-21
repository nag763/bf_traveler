# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 7

  tags = local.tags
}

# SSM Parameter for NextAuth Secret
resource "aws_ssm_parameter" "nextauth_secret" {
  name  = "/${local.name_prefix}/nextauth-secret"
  type  = "SecureString"
  value = var.nextauth_secret

  tags = local.tags
}