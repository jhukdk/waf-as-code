# Remote state backend. Bucket is created by the one-off config in
# bootstrap/ (which keeps its own state local on purpose).
terraform {
  backend "s3" {
    bucket       = "waf-as-code-tfstate-20260611030653684900000001"
    key          = "waf-as-code/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
