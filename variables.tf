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

variable "geo_count_countries" {
  description = "Countries counted (not blocked) by the geo-match rule. Defaults include US so demo traffic shows up in logs without being blocked."
  type        = list(string)
  default     = ["US", "CA"]
}
