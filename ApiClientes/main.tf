provider "aws" {
  region = "us-east-1"
}

resource "aws_api_gateway_rest_api" "sandbox_api" {
  name = "SandboxAPI"
}

resource "aws_api_gateway_resource" "custom_path" {
  rest_api_id = aws_api_gateway_rest_api.sandbox_api.id
  parent_id   = aws_api_gateway_rest_api.sandbox_api.root_resource_id
  path_part   = "custom-path"
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
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.sandbox_api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_db_subnet_group" "sandbox_subnet_group" {
  name       = "sandbox-subnet-group"
  subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  tags = {
    Name = "Tech Challenge DB Subnet Group"
  }
}

resource "aws_security_group" "rds_sg" {
  name   = "rds-security-group"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "sandbox_db" {
  identifier              = "sandbox-db"
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.sandbox_subnet_group.name
  skip_final_snapshot     = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
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
  handler          = "index.handler"
  runtime          = "python3.11"
  filename         = "${path.module}/function.zip"
  source_code_hash = filebase64sha256("${path.module}/function.zip")

  environment {
    variables = {
      DB_PASSWORD = var.db_password
      DB_USERNAME = var.db_username
      DB_HOST     = aws_db_instance.sandbox_db.endpoint
      DB_NAME     = var.db_name
    }
  }
}
