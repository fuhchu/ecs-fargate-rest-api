# ===========================================================================
# CI/CD authentication: GitHub Actions -> AWS via OpenID Connect (OIDC).
#
# No long-lived AWS keys are stored in GitHub. Instead, GitHub presents a
# short-lived signed token for each workflow run, and AWS issues temporary
# credentials only if the token's claims match the trust policy below.
# ===========================================================================

# Fetch GitHub's OIDC TLS certificate so we can register its fingerprint
# without hardcoding a thumbprint that may rotate.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# Register GitHub as a trusted OIDC identity provider in this AWS account.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"] # the "audience" the token must target
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = { Name = "${var.name}-github-oidc" }
}

# ---- Trust policy: WHO may assume the CI role, and under WHAT conditions ----
data "aws_iam_policy_document" "github_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # The token's audience must be sts.amazonaws.com.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # The token's subject must be THIS repo on the main branch. This is the
    # least-privilege scope: no other repo, and no other branch, can assume the
    # role — so a fork or a feature branch cannot touch AWS.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
  tags               = { Name = "${var.name}-github-actions" }
}

# ---- Permissions: what the CI role is allowed to DO once assumed ----
# Scoped to exactly the ECR repo and ECS actions the pipeline needs.
data "aws_iam_policy_document" "github_actions_permissions" {
  # ECR login token is account-wide and cannot be resource-scoped.
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push/pull image layers — limited to OUR repository.
  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  # Register a new task-definition revision and roll the service to it.
  # Several of these actions don't support resource-level scoping, hence "*".
  statement {
    sid = "EcsDeploy"
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
    ]
    resources = ["*"]
  }

  # Registering/running a task definition requires permission to PASS the two
  # task roles to ECS. Scoped to exactly those roles, only for the ECS service.
  statement {
    sid       = "PassEcsRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task_execution.arn, aws_iam_role.task.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.name}-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
