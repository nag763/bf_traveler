# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-user-pool"

  # Prevent self-registration
  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      email_message = "Your username is {username} and password is {####}. You can sign in directly without changing the password."
      email_subject = "Your account for ${var.project_name}"
      sms_message   = "Your username is {username} and password is {####}"
    }
  }

  # Relaxed password policy for development
  password_policy {
    minimum_length    = 6
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

  # User attributes
  alias_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  tags = local.tags
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name         = "${local.name_prefix}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth settings
  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Callback URLs - Required for OAuth flows
  callback_urls = [
    "http://localhost:3000/api/auth/callback/cognito",
    "https://localhost:3000/api/auth/callback/cognito"
  ]

  # Logout URLs
  logout_urls = [
    "http://localhost:3000/auth/signin",
    "https://localhost:3000/auth/signin"
  ]

  # Token validity
  access_token_validity  = 60 # 1 hour
  id_token_validity      = 60 # 1 hour
  refresh_token_validity = 30 # 30 days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  depends_on = [aws_cognito_user_pool.main]
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.name_prefix}-auth-${random_string.domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Random string for unique domain
resource "random_string" "domain_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Demo user (optional - for testing)
resource "aws_cognito_user" "demo_user" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "demouser"

  attributes = {
    email          = "demo@example.com"
    email_verified = "true"
  }

  password       = "demo123"  # Permanent password, no change required
  message_action = "SUPPRESS" # Don't send welcome email

  lifecycle {
    ignore_changes = [
      password
    ]
  }
}

# Store Cognito configuration in SSM
resource "aws_ssm_parameter" "cognito_user_pool_id" {
  name  = "/${local.name_prefix}/cognito/user-pool-id"
  type  = "String"
  value = aws_cognito_user_pool.main.id

  tags = local.tags
}

resource "aws_ssm_parameter" "cognito_client_id" {
  name  = "/${local.name_prefix}/cognito/client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.main.id

  tags = local.tags
}

resource "aws_ssm_parameter" "cognito_client_secret" {
  name  = "/${local.name_prefix}/cognito/client-secret"
  type  = "SecureString"
  value = aws_cognito_user_pool_client.main.client_secret

  tags = local.tags
}

resource "aws_ssm_parameter" "cognito_domain" {
  name  = "/${local.name_prefix}/cognito/domain"
  type  = "String"
  value = aws_cognito_user_pool_domain.main.domain

  tags = local.tags
}

resource "aws_ssm_parameter" "cognito_issuer" {
  name  = "/${local.name_prefix}/cognito/issuer"
  type  = "String"
  value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"

  tags = local.tags
}
