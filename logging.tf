# WAF logging destination. The log group name MUST start with
# "aws-waf-logs-" or PutLoggingConfiguration is rejected.
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-demo"
  retention_in_days = 3
}

resource "aws_wafv2_web_acl_logging_configuration" "demo" {
  resource_arn            = aws_wafv2_web_acl.demo.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}
