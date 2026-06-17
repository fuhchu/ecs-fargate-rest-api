# Input variables for the network. Defaults are sensible for this project;
# expressing them as variables (rather than hardcoding) is the production habit
# that lets the same code build dev/staging/prod with different values later.

variable "name" {
  description = "Name prefix stamped onto resources, so they're easy to spot and clean up."
  type        = string
  default     = "items-api"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. A /16 gives ~65k addresses — plenty of room to carve subnets."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One CIDR per public subnet (one per AZ). Hosts the ALB and NAT gateways."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "One CIDR per private subnet (one per AZ). Hosts the Fargate tasks."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "container_port" {
  description = "Port the application listens on inside the container (uvicorn binds here)."
  type        = number
  default     = 8000
}

variable "aws_region" {
  description = "AWS region to deploy into. (The backend region is set separately in backend.tf.)"
  type        = string
  default     = "us-west-2"
}

variable "image_tag" {
  description = "Tag of the application image in ECR to run. CI will override this per build later."
  type        = string
  default     = "0.1.0"
}

variable "github_repository" {
  description = "GitHub repo (owner/name) permitted to assume the CI role via OIDC."
  type        = string
  default     = "fuhchu/ecs-fargate-rest-api"
}
