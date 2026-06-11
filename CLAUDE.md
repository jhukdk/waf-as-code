# WAF-as-Code Demo Project

## Purpose
Interview demo project (built tonight, presented tomorrow) proving hands-on
skill with: AWS WAFv2 configuration, custom rule development, IaC (Terraform),
and CI/CD for security config. Optimize for: working, demonstrable, cheap.
Not for: production hardening, multi-region, multi-account.

## Stack
- Terraform >= 1.10, AWS provider ~> 5.x, region us-east-1 only
- AWS WAFv2 Web ACL, scope REGIONAL
- Protected resource: API Gateway REST API (regional endpoint type) with a
  MOCK integration returning 200 + small JSON body, stage name `prod`
- WAF logging -> CloudWatch log group named `aws-waf-logs-demo` (the
  `aws-waf-logs-` prefix is mandatory or logging config fails)
- Remote state: S3 bucket, native locking via `use_lockfile = true`
  (no DynamoDB table)
- CI/CD: GitHub Actions. plan.yml on pull_request (fmt-check, validate,
  tflint, plan). apply.yml on push to main. Auth via GitHub OIDC -> IAM
  role (no long-lived AWS keys in repo secrets).

## WAF rule set (priority order)
1. Rate-based rule: 100 requests / 5 min per IP -> block. Lowest priority
   number (evaluated first among our rules).
2. AWSManagedRulesCommonRuleSet — with rule_action_override setting
   SizeRestrictions_BODY to count (demonstrates tuning workflow).
3. AWSManagedRulesKnownBadInputsRuleSet — default actions.
4. Custom geo-match rule: count (not block) requests from two example
   countries, so logs show the rule firing without breaking demos.
5. Custom byte-match/regex rule: block requests containing header
   `x-demo-attack` (any value) -> 403. This is the deterministic
   "show a custom rule blocking" demo for the interview.
   (Implemented as a size_constraint GE 0 on the header, since
   byte-match can't express "header present with any value".)
6. AWSManagedRulesSQLiRuleSet — default actions. Added after
   tests/attack-sim.sh case 2 caught that neither CommonRuleSet nor
   KnownBadInputs blocks SQLi (good interview story).
- Every rule and the web ACL itself must have CloudWatch metrics enabled
  and sampled requests on.

## File layout
providers.tf, versions.tf, backend.tf, variables.tf, outputs.tf,
api.tf, waf.tf, logging.tf, oidc.tf, .github/workflows/{plan,apply}.yml,
tests/attack-sim.sh, README.md

## Hard rules
- NEVER run `terraform apply` or `terraform destroy` without asking me
  first and showing me the plan summary.
- Never create IAM users or access keys; OIDC role only for CI.
- Never hardcode account IDs, ARNs with secrets, or credentials in files;
  use variables/data sources.
- Smallest/cheapest resources everywhere. No NAT gateways, no ALBs,
  no EC2, no KMS CMKs (AWS-managed keys fine).
- Outputs must include the API invoke URL and the web ACL ARN.
- After any change to waf.tf, run `terraform validate` and `terraform plan`
  before telling me it's done.
- Conventional, descriptive commit messages; commit at phase boundaries
  when I say so.

## Testing convention
tests/attack-sim.sh takes the invoke URL as $1 and runs:
1. Baseline GET -> expect 200
2. SQLi-style query string (?id=1' OR '1'='1) -> expect 403 (managed rules)
3. GET with header `x-demo-attack: 1` -> expect 403 (custom rule)
4. Loop of 150 rapid requests -> expect 200s turning into 403s (rate rule;
   note rate rules can take ~1-2 min of sustained traffic to trip)
Print PASS/FAIL per case with the HTTP code received.