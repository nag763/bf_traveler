output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_domain" {
  description = "Cognito User Pool Domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_hosted_ui_url" {
  description = "Cognito Hosted UI URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "demo_user_info" {
  description = "Demo user credentials"
  value = {
    username = aws_cognito_user.demo_user.username
    email    = "demo@example.com"
    password = "demo123"
    note     = "Sign in with email address, no password change required"
  }
}

output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.chat_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.chat_api_stage.stage_name}"
}

output "chat_api_endpoint" {
  description = "Chat API endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.chat_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.chat_api_stage.stage_name}/chat"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.chat_handler.function_name
}