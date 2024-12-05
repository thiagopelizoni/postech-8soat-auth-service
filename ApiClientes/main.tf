provider "aws" {
  region = "us-east-1"
}

resource "aws_api_gateway_rest_api" "sandbox_api" {
  name = "SandboxAPI"
}

resource "aws_api_gateway_resource" "custom_path" {
  rest_api_id = aws_api_gateway_rest_api.sandbox_api.id
  parent_id   = aws_api_gateway_rest_api.sandbox_api.root_resource_id
  path_part   = "login"
}

resource "aws_api_gateway_method" "custom_method" {
  rest_api_id   = aws_api_gateway_rest_api.sandbox_api.id
  resource_id   = aws_api_gateway_resource.custom_path.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sandbox_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_integration" "custom_integration" {
  rest_api_id             = aws_api_gateway_rest_api.sandbox_api.id
  resource_id             = aws_api_gateway_resource.custom_path.id
  http_method             = aws_api_gateway_method.custom_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.sandbox_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.sandbox_api.id

  triggers = {
    redeployment = sha1(jsonencode([aws_lambda_function.sandbox_lambda.source_code_hash]))
  }

  depends_on = [
    aws_api_gateway_integration.custom_integration
  ]
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.sandbox_api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" },
      Effect    = "Allow",
      Sid       = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "sandbox_lambda" {
  function_name    = "Sandbox"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = "${path.module}/function.zip"
  source_code_hash = filebase64sha256("${path.module}/function.zip")
}

resource "aws_cognito_user_pool" "user_pool" {
  name = "SandboxUserPool"

  schema {
    name               = "cpf"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  schema {
    name               = "nome"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  schema {
    name               = "data_nascimento"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "SandboxUserPoolClient"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

output "api_gateway_endpoint" {
  value = aws_api_gateway_stage.prod.invoke_url
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.user_pool_client.id
}
