output "api_invoke_url" {
  description = "Invoke URL of the prod stage"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "web_acl_arn" {
  description = "ARN of the WAFv2 web ACL"
  value       = aws_wafv2_web_acl.demo.arn
}
