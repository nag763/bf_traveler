# Lambda function for chat handling
resource "aws_lambda_function" "chat_handler" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${local.name_prefix}-chat-handler"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
      MCP_LAMBDA_API_URL = "https://${aws_api_gateway_rest_api.chat_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}/mcp"
    }
  }

  tags = local.tags
}

# Create ZIP file for Lambda deployment
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/chat_handler"
  output_path = "${path.root}/lambda_function.zip"
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.name_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "lambda_bedrock_policy" {
  name        = "lambda-bedrock-policy"
  description = "Allows Lambda to invoke Bedrock models and write logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:eu-*:*:inference-profile/*",
          "arn:aws:bedrock:eu-*::foundation-model/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:logs:*:*:*",
          aws_lambda_function.mcp_handler.arn,
          aws_lambda_function.chat_handler.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = [
          "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.chat_api.id}/${aws_api_gateway_stage.chat_api_stage.stage_name}/POST/mcp"
        ]
      }
    ]
  })
}

# Attach basic execution policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_bedrock_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_bedrock_policy.arn
}

# CloudWatch Log Group for chat_handler Lambda
resource "aws_cloudwatch_log_group" "chat_handler_logs" {
  name              = "/aws/lambda/${aws_lambda_function.chat_handler.function_name}"
  retention_in_days = 14

  tags = local.tags
}

# Lambda permission for API Gateway to invoke chat_handler
resource "aws_lambda_permission" "api_gateway_invoke_chat_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/*"
}

# Lambda permission for API Gateway to invoke mcp_handler
resource "aws_lambda_permission" "api_gateway_invoke_mcp_handler" {
  statement_id  = "AllowExecutionFromAPIGatewayMcp"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mcp_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/*"
}

# Lambda function for MCP handling
resource "aws_lambda_function" "mcp_handler" {
  filename      = data.archive_file.mcp_lambda_zip.output_path
  function_name = "${local.name_prefix}-mcp-handler"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "run.sh"     # Node.js handler
  runtime       = "nodejs22.x" # Node.js runtime
  timeout       = 30
  memory_size   = 256

  source_code_hash = data.archive_file.mcp_lambda_zip.output_base64sha256

  layers = [
    "arn:aws:lambda:${var.aws_region}:753240598075:layer:LambdaAdapterLayerX86:25"
  ]

  environment {
    variables = {
      LOG_LEVEL               = "INFO"
      AWS_LWA_PORT            = "3000"
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/bootstrap"
    }
  }



  tags = local.tags
}

# Create ZIP file for MCP_handler Lambda deployment
data "archive_file" "mcp_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/mcp_handler"
  output_path = "${path.root}/mcp_lambda_function.zip"
}

# CloudWatch Log Group for MCP_handler Lambda
resource "aws_cloudwatch_log_group" "mcp_handler_logs" {
  name              = "/aws/lambda/${aws_lambda_function.mcp_handler.function_name}"
  retention_in_days = 14

  tags = local.tags
}

# Lambda permission for chat_handler to invoke MCP_handler
resource "aws_lambda_permission" "chat_handler_invoke_mcp_handler" {
  statement_id  = "AllowChatHandlerToInvokeMcpHandler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mcp_handler.function_name
  principal     = "lambda.amazonaws.com"
  source_arn    = aws_lambda_function.chat_handler.arn
}
