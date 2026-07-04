# ---------- CREATE TASK ----------
data "archive_file" "create_task" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/create_task"
  output_path = "${path.module}/build/create_task.zip"
}

resource "aws_lambda_function" "create_task" {
  function_name    = "${var.project_name}-create-task"
  filename         = data.archive_file.create_task.output_path
  source_code_hash = data.archive_file.create_task.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todo_table.name
    }
  }
}

# ---------- READ TASKS ----------
data "archive_file" "read_tasks" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/read_tasks"
  output_path = "${path.module}/build/read_tasks.zip"
}

resource "aws_lambda_function" "read_tasks" {
  function_name    = "${var.project_name}-read-tasks"
  filename         = data.archive_file.read_tasks.output_path
  source_code_hash = data.archive_file.read_tasks.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todo_table.name
    }
  }
}

# ---------- UPDATE TASK ----------
data "archive_file" "update_task" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/update_task"
  output_path = "${path.module}/build/update_task.zip"
}

resource "aws_lambda_function" "update_task" {
  function_name    = "${var.project_name}-update-task"
  filename         = data.archive_file.update_task.output_path
  source_code_hash = data.archive_file.update_task.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todo_table.name
    }
  }
}

# ---------- DELETE TASK ----------
data "archive_file" "delete_task" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/delete_task"
  output_path = "${path.module}/build/delete_task.zip"
}

resource "aws_lambda_function" "delete_task" {
  function_name    = "${var.project_name}-delete-task"
  filename         = data.archive_file.delete_task.output_path
  source_code_hash = data.archive_file.delete_task.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todo_table.name
    }
  }
}

# ---------- AUTHORIZER ----------
data "archive_file" "authorizer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/authorizer"
  output_path = "${path.module}/build/authorizer.zip"
}

resource "aws_lambda_function" "authorizer" {
  function_name    = "${var.project_name}-authorizer"
  filename         = data.archive_file.authorizer.output_path
  source_code_hash = data.archive_file.authorizer.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10

  environment {
    variables = {
      USER_POOL_ID  = aws_cognito_user_pool.this.id
      APP_CLIENT_ID = aws_cognito_user_pool_client.this.id
    }
  }
}

resource "aws_lambda_permission" "authorizer_invoke" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}