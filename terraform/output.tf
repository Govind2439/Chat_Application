output "user_pool_id" {
  value = aws_cognito_user_pool.chat_user_pool.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.chat_user_pool_client.id
}

output "identity_pool_id" {
  value = aws_cognito_identity_pool.chat_identity_pool.id
}

output "graphql_api_url" {
  value = aws_appsync_graphql_api.chat_api.uris["GRAPHQL"]
}

output "api_key" {
  value = aws_appsync_api_key.chat_api_key.id
}

