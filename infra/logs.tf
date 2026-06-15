# CloudWatch Log Group — destination for the container's stdout/stderr.
# The ECS task definition (4c) points its log driver here.

resource "aws_cloudwatch_log_group" "app" {
  name = "/ecs/${var.name}"

  # Don't retain logs forever — that costs money and is rarely useful for a
  # demo. 14 days is a sensible default you can defend in an interview.
  retention_in_days = 14

  tags = { Name = "${var.name}-logs" }
}
