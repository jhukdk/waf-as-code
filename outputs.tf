output "api_invoke_url" {
  description = "Invoke URL of the prod stage"
  value       = aws_api_gateway_stage.prod.invoke_url
}
