# Lambda function for chat handling
resource "aws_lambda_function" "chat_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.name_prefix}-chat-handler"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.12"
  timeout         = 30
  memory_size     = 256

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
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
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
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

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.chat_handler.function_name}"
  retention_in_days = 14

  tags = local.tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/*"
}