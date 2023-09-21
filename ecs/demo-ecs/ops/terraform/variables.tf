variable "cloudwatch_group" {
  description = "CloudWatch group name."
  type = string
  default = "/ecs/demo-ecs"
}

variable "region" {
  description = "aws region"
  type = string
  default = "us-east-1"
}

variable "logs_retention_in_days" {
  type        = number
  default     = 90
  description = "Specifies the number of days you want to retain log events"
}