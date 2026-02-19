output "api_gateway_invoke_url" {
  description = "The invoke URL for the API Gateway stage."
  value       = aws_api_gateway_stage.api_stage.invoke_url
}
