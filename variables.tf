variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used for resource naming and tagging"
  type        = string
  default     = "waf-as-code"
}
