variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "todo-api"
}

variable "alert_email" {
  description = "E-mail para receber alertas de custo"
  type        = string
}