provider "aws" {
  region = "us-west-2"
}

resource "aws_cognito_user_pool" "chat_user_pool" {
  name = "chat_user_pool"
}

resource "aws_cognito_user_pool_client" "chat_user_pool_client" {
  name         = "chat_user_pool_client"
  user_pool_id = aws_cognito_user_pool.chat_user_pool.id
  generate_secret = false
}

resource "aws_cognito_identity_pool" "chat_identity_pool" {
  identity_pool_name               = "chat_identity_pool"
  allow_unauthenticated_identities = false
  cognito_identity_providers {
    client_id = aws_cognito_user_pool_client.chat_user_pool_client.id
    provider_name = "cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.chat_user_pool.id}"
  }
}

resource "aws_dynamodb_table" "chat_messages" {
  name           = "chat_messages"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "message_id"
  range_key      = "timestamp"

  attribute {
    name = "message_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "lambda_policy"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "dynamodb:PutItem",
            "dynamodb:GetItem",
            "dynamodb:Scan",
            "dynamodb:Query"
          ],
          Effect   = "Allow",
          Resource = aws_dynamodb_table.chat_messages.arn
        },
        {
          Action = "logs:*",
          Effect   = "Allow",
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_lambda_function" "manage_messages" {
  function_name = "manage_messages"
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "nodejs14.x"
  handler       = "index.handler"
  filename      = "lambdas/manage_messages.zip"

  source_code_hash = filebase64sha256("lambdas/manage_messages.zip")
}

resource "aws_appsync_graphql_api" "chat_api" {
  name = "chat_api"
  authentication_type = "AMAZON_COGNITO_USER_POOLS"

  user_pool_config {
    user_pool_id = aws_cognito_user_pool.chat_user_pool.id
    aws_region   = var.region
    default_action = "ALLOW"
  }
}

resource "aws_appsync_api_key" "chat_api_key" {
  api_id = aws_appsync_graphql_api.chat_api.id
}

resource "aws_appsync_datasource" "dynamodb" {
  api_id = aws_appsync_graphql_api.chat_api.id
  name   = "DynamoDBMessages"
  type   = "AMAZON_DYNAMODB"
  
  dynamodb_config {
    table_name = aws_dynamodb_table.chat_messages.name
    aws_region = var.region
  }

  service_role_arn = aws_iam_role.lambda_exec_role.arn
}

resource "aws_appsync_resolver" "list_messages" {
  api_id          = aws_appsync_graphql_api.chat_api.id
  type            = "Query"
  field           = "listMessages"
  data_source     = aws_appsync_datasource.dynamodb.name

  request_template = file("${path.module}/templates/listMessages-request.vtl")
  response_template = file("${path.module}/templates/listMessages-response.vtl")
}

resource "aws_appsync_resolver" "create_message" {
  api_id          = aws_appsync_graphql_api.chat_api.id
  type            = "Mutation"
  field           = "createMessage"
  data_source     = aws_appsync_datasource.dynamodb.name

  request_template = file("${path.module}/templates/createMessage-request.vtl")
  response_template = file("${path.module}/templates/createMessage-response.vtl")
}

output "graphql_api_url" {
  value = aws_appsync_graphql_api.chat_api.uris["GRAPHQL"]
}

output "api_key" {
  value = aws_appsync_api_key.chat_api_key.id
}

