output "api_url" {
  value = aws_apigatewayv2_stage.prod.invoke_url
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.this.id
}