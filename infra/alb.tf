# ===========================================================================
# Application Load Balancer (ALB): the public entry point.
#
#   internet --> ALB (:80, public subnets) --> target group --> tasks (:8000)
#
# The ALB health-checks each task at /health; only tasks returning 200 receive
# traffic. This is where the health endpoint from Milestone 1 pays off.
# ===========================================================================

resource "aws_lb" "main" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false # internet-facing
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id # ALB lives in the public subnets

  tags = { Name = "${var.name}-alb" }
}

# Target group: the pool of backends the ALB forwards to.
# target_type = "ip" is REQUIRED for Fargate, because awsvpc networking gives
# each task its own private IP (rather than an EC2 instance + port).
resource "aws_lb_target_group" "app" {
  name        = "${var.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30 # check every 30s
    timeout             = 5  # fail a check that takes >5s
    healthy_threshold   = 2  # 2 passes in a row => healthy
    unhealthy_threshold = 3  # 3 fails in a row  => unhealthy, stop routing
  }

  tags = { Name = "${var.name}-tg" }
}

# Listener: accept HTTP on :80 and forward everything to the target group.
#   Production note: real production adds an HTTPS (:443) listener with an ACM
#   certificate and redirects :80 -> :443. That needs a domain name, so we keep
#   plain HTTP here and note TLS as a documented future improvement.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
