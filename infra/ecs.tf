# ===========================================================================
# ECS on Fargate: cluster, task definition, and service.
# This is what turns the image in ECR into a running, load-balanced API.
# ===========================================================================

# ---- Cluster: a logical home for the service/tasks ----
resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster"

  # Container Insights adds CloudWatch metrics/dashboards but costs extra.
  # Off for Project 1; Project 4 is dedicated to full observability.
  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = { Name = "${var.name}-cluster" }
}

# ---- Task definition: the blueprint for one running container ----
resource "aws_ecs_task_definition" "app" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # required for Fargate; gives the task its own ENI/IP
  cpu                      = 256      # 0.25 vCPU
  memory                   = 512      # 0.5 GB (MiB)

  execution_role_arn = aws_iam_role.task_execution.arn # to pull image + write logs
  task_role_arn      = aws_iam_role.task.arn           # the app's own identity (no perms)

  # Pin the platform explicitly. Gotcha worth knowing: an image built on an ARM
  # machine (e.g. Apple Silicon) is arm64 and will fail to start on an X86_64
  # task. Being explicit prevents that "works locally, fails on Fargate" class
  # of bug.
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      # Ship stdout/stderr to the CloudWatch log group from 4a.
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "${var.name}-task" }
}

# ---- Service: keeps the desired number of tasks running and load-balanced ----
resource "aws_ecs_service" "app" {
  name            = "${var.name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2 # two tasks for HA — ECS spreads them across the two AZs
  launch_type     = "FARGATE"

  # Give a freshly started task time to boot before ALB health checks count
  # against it (prevents healthy tasks being killed during slow startup).
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = aws_subnet.private[*].id    # tasks run in the PRIVATE subnets
    security_groups  = [aws_security_group.task.id] # reachable only from the ALB
    assign_public_ip = false                        # no public IP; egress via NAT
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.name
    container_port   = var.container_port
  }

  # Production resilience: if a deployment's new tasks fail to become healthy,
  # automatically roll back to the last good version instead of staying broken.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # The service registers into the target group, so the listener must exist first.
  depends_on = [aws_lb_listener.http]

  lifecycle {
    # The CI/CD pipeline (Milestone 5) registers a new task-definition revision
    # on every deploy and points the service at it. Ignoring task_definition
    # here means a later `terraform apply` won't roll the service back to the
    # revision Terraform created. The boundary: Terraform owns the
    # infrastructure shape; the pipeline owns which image version is deployed.
    ignore_changes = [task_definition]
  }

  tags = { Name = "${var.name}-service" }
}
