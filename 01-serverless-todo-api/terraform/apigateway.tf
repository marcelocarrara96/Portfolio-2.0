resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_authorizer" "lambda" {
  api_id                            = aws_apigatewayv2_api.this.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  name                              = "lambda-authorizer"
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = false
  authorizer_result_ttl_in_seconds  = 0 # <-- adiciona essa linha
}

# ---------- CREATE ----------
resource "aws_apigatewayv2_integration" "create_task" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_task.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_task" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "POST /tasks"
  target             = "integrations/${aws_apigatewayv2_integration.create_task.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id
}

resource "aws_lambda_permission" "create_task" {
  statement_id  = "AllowAPIGatewayInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---------- READ ----------
resource "aws_apigatewayv2_integration" "read_tasks" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.read_tasks.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "read_tasks" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /tasks"
  target             = "integrations/${aws_apigatewayv2_integration.read_tasks.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id
}

resource "aws_lambda_permission" "read_tasks" {
  statement_id  = "AllowAPIGatewayInvokeRead"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read_tasks.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---------- UPDATE ----------
resource "aws_apigatewayv2_integration" "update_task" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.update_task.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "update_task" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "PUT /tasks/{taskId}"
  target             = "integrations/${aws_apigatewayv2_integration.update_task.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id
}

resource "aws_lambda_permission" "update_task" {
  statement_id  = "AllowAPIGatewayInvokeUpdate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---------- DELETE ----------
resource "aws_apigatewayv2_integration" "delete_task" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.delete_task.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "delete_task" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "DELETE /tasks/{taskId}"
  target             = "integrations/${aws_apigatewayv2_integration.delete_task.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id
}

resource "aws_lambda_permission" "delete_task" {
  statement_id  = "AllowAPIGatewayInvokeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---------- STAGE ----------
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "prod"
  auto_deploy = true
}