# GitHub Actions OIDC federation: CI assumes a role scoped to this repo
# instead of using long-lived AWS keys in repo secrets.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    # AWS validates GitHub's cert against trusted root CAs and ignores
    # these, but the API still requires at least one value.
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only workflows in this repo (any branch/PR ref) can assume the role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  description        = "Assumed by GitHub Actions in ${var.github_repo} via OIDC for terraform plan/apply"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# Demo tradeoff, made deliberately: the repo-scoped trust policy is the
# security boundary; permissions are broad so CI never stalls on
# AccessDenied. Swap for a scoped policy (wafv2/apigateway/logs/iam on
# this role + state bucket S3 access) before any real-world use.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_role_arn" {
  description = "IAM role ARN for the GitHub Actions workflows"
  value       = aws_iam_role.github_actions.arn
}
