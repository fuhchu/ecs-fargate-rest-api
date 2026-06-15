# ===========================================================================
# IAM roles for ECS.
#
# Two distinct roles — a favourite interview topic:
#   - Task EXECUTION role: used by the ECS agent to pull the image from ECR and
#     ship logs to CloudWatch. Permissions to *start* the container.
#   - Task role: the identity the *application* runs as for its own AWS calls.
#     Our app makes none, so it gets no policies (least privilege made literal).
# ===========================================================================

# Trust policy shared by both roles: allow the ECS tasks service to assume them.
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---- Task execution role ----
resource "aws_iam_role" "task_execution" {
  name               = "${var.name}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Name = "${var.name}-task-execution" }
}

# AWS-managed policy granting exactly the ECR-pull + CloudWatch-logs permissions
# the execution role needs. Using the managed policy (not a hand-rolled one) is
# the recommended, least-surprise approach.
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---- Task role ----
# Created to show the distinction, but intentionally has NO policies attached:
# the application calls no AWS services, so it should be granted nothing.
resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Name = "${var.name}-task" }
}
