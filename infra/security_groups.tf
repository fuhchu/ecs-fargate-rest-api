# ===========================================================================
# Security groups (stateful firewalls).
#
# The core rule: the tasks accept traffic ONLY from the ALB's security group,
# referenced by ID — not by IP range, and not from the internet. The load
# balancer is the single front door to the application.
#
# We use the newer single-rule resources (aws_vpc_security_group_*_rule) rather
# than inline ingress/egress blocks — the provider-recommended approach, and
# each rule is independently tracked in state.
# ===========================================================================

# ---- ALB security group: public-facing ----
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Allow inbound HTTP to the ALB from the internet"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound (to forward to tasks)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # -1 = all protocols
}

# ---- Task security group: reachable only from the ALB ----
resource "aws_security_group" "task" {
  name        = "${var.name}-task-sg"
  description = "Allow inbound on the app port from the ALB only"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.name}-task-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "App port, from the ALB security group only"
  referenced_security_group_id = aws_security_group.alb.id # <-- the key line
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "task_all" {
  security_group_id = aws_security_group.task.id
  description       = "Allow all outbound (reach ECR/CloudWatch via NAT)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
