# API Gateway REST API
resource "aws_api_gateway_rest_api" "chat_api" {
  name        = "${local.name_prefix}-chat-api"
  description = "Chat API with Cognito authentication"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.tags
}

# Cognito User Pool Authorizer
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name                   = "${local.name_prefix}-cognito-authorizer"
  rest_api_id           = aws_api_gateway_rest_api.chat_api.id
  type                  = "COGNITO_USER_POOLS"
  provider_arns         = [aws_cognito_user_pool.main.arn]
  identity_source       = "method.request.header.Authorization"
  authorizer_credentials = aws_iam_role.api_gateway_cognito_role.arn
}

# IAM role for API Gateway to access Cognito
resource "aws_iam_role" "api_gateway_cognito_role" {
  name = "${local.name_prefix}-api-gateway-cognito-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# API Gateway resource for chat endpoint
resource "aws_api_gateway_resource" "chat_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_rest_api.chat_api.root_resource_id
  path_part   = "chat"
}

# POST method for chat endpoint
resource "aws_api_gateway_method" "chat_post" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.chat_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

# OPTIONS method for CORS preflight
resource "aws_api_gateway_method" "chat_options" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.chat_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Integration for POST method with Lambda
resource "aws_api_gateway_integration" "chat_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.chat_handler.invoke_arn
}

# Integration for OPTIONS method (CORS)
resource "aws_api_gateway_integration" "chat_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_options.http_method

  type = "MOCK"
  
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# Method response for POST
resource "aws_api_gateway_method_response" "chat_post_response" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

# Method response for OPTIONS (CORS)
resource "aws_api_gateway_method_response" "chat_options_response" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

# Integration response for POST
resource "aws_api_gateway_integration_response" "chat_post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_post.http_method
  status_code = aws_api_gateway_method_response.chat_post_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }

  depends_on = [aws_api_gateway_integration.chat_post_integration]
}

# Integration response for OPTIONS (CORS)
resource "aws_api_gateway_integration_response" "chat_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = aws_api_gateway_method_response.chat_options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }

  depends_on = [aws_api_gateway_integration.chat_options_integration]
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "chat_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.chat_resource.id,
      aws_api_gateway_method.chat_post.id,
      aws_api_gateway_method.chat_options.id,
      aws_api_gateway_integration.chat_post_integration.id,
      aws_api_gateway_integration.chat_options_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.chat_post,
    aws_api_gateway_method.chat_options,
    aws_api_gateway_integration.chat_post_integration,
    aws_api_gateway_integration.chat_options_integration,
  ]
}

# IAM role for API Gateway CloudWatch logging
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "${local.name_prefix}-api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Attach CloudWatch logs policy to API Gateway role
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_logs" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
}

# API Gateway account settings for CloudWatch logging
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}

# API Gateway stage
resource "aws_api_gateway_stage" "chat_api_stage" {
  deployment_id = aws_api_gateway_deployment.chat_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      caller        = "$context.identity.caller"
      user          = "$context.identity.user"
      requestTime   = "$context.requestTime"
      httpMethod    = "$context.httpMethod"
      resourcePath  = "$context.resourcePath"
      status        = "$context.status"
      protocol      = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  depends_on = [aws_api_gateway_account.main]

  tags = local.tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.chat_api.name}"
  retention_in_days = 14

  tags = local.tags
}