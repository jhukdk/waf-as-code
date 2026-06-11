resource "aws_wafv2_web_acl" "demo" {
  name        = "${var.project_name}-web-acl"
  description = "Demo web ACL for the waf-as-code project"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # 1. Rate limit: 100 requests / 5 min per source IP -> block.
  rule {
    name     = "rate-limit-per-ip"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = 100
        evaluation_window_sec = 300
        aggregate_key_type    = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  # 2. AWS Common Rule Set, with SizeRestrictions_BODY downgraded to
  #    count to demonstrate the rule-tuning workflow.
  rule {
    name     = "aws-common-rule-set"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "SizeRestrictions_BODY"

          action_to_use {
            count {}
          }
        }

        # Uptime monitors and internal health-check probes often send no
        # User-Agent and were showing up as blocks on this sub-rule. Count
        # instead of block; the rate limit and the other CommonRuleSet
        # sub-rules still apply to that traffic. Revisit if the
        # NoUserAgent_HEADER count metric shows abuse rather than monitors.
        rule_action_override {
          name = "NoUserAgent_HEADER"

          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # 3. AWS Known Bad Inputs, default actions.
  rule {
    name     = "aws-known-bad-inputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # 4. Geo-match in count mode: fires in logs/metrics on demo traffic
  #    without blocking anything.
  rule {
    name     = "geo-match-count"
    priority = 4

    action {
      count {}
    }

    statement {
      geo_match_statement {
        country_codes = var.geo_count_countries
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "geo-match-count"
      sampled_requests_enabled   = true
    }
  }

  # 5. Deterministic custom-rule demo: any request carrying the
  #    x-demo-attack header (any value) is blocked with a 403.
  rule {
    name     = "block-x-demo-attack-header"
    priority = 5

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        comparison_operator = "GE"
        size                = 0

        field_to_match {
          single_header {
            name = "x-demo-attack"
          }
        }

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "block-x-demo-attack-header"
      sampled_requests_enabled   = true
    }
  }

  # 6. SQLi detection. Added after tests/attack-sim.sh case 2 exposed that
  #    neither CommonRuleSet nor KnownBadInputs inspects for SQL injection.
  rule {
    name     = "aws-sqli-rule-set"
    priority = 6

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-sqli-rule-set"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-web-acl"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "prod_stage" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.demo.arn
}
