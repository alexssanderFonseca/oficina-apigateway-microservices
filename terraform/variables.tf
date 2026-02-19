variable "api_name" {
  description = "The name of the API Gateway."
  default     = "oficina-api"
}

variable "api_stage_name" {
  description = "The name of the API Gateway stage."
  default     = "dev"
}

variable "aws_region" {
  description = "The AWS region to create resources in."
  default     = "us-east-1"
}
