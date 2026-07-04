resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-user-pool"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_numbers   = true
  }

  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.this.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  generate_secret = false
}