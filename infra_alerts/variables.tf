variable "resource_prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "name" {
  description = "Name of all resources"
  type        = string
}

variable "lambda_filename" {
  description = "Filename of the lambda function"
  type        = string
  default     = "lambda.py"
}

variable "lambda_handler" {
  description = "Lambda handler"
  type        = string
  default     = "lambda.handler"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_architectures" {
  description = "Lambda architectures, valid options [\"x86_64\"] and [\"arm6\"]"
  type        = list(string)
  default     = ["arm64"]
}

variable "lambda_memory_size" {
  description = "Lambda memory size"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "lambda_env_vars" {
  description = "Lambda environment variables"
  type        = map(any)
  default     = {}
}

variable "elasticache_member_clusters" {
  description = "List of Cluster IDs"
  type        = list(string)
  default     = []
}

variable "rds_serverlessv2_max_capacity" {
  description = "Serverless v2 max ACU capacity"
  type        = number
  default     = null
}

variable "p1_alerts_email_subscribers" {
  description = "Email address subscribers for P1 alerts"
  type        = list(string)
  default     = []
}