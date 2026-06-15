# ===========================================================================
# Elastic Container Registry (ECR) — the private registry that stores the
# application's Docker image so ECS Fargate can pull it.
# ===========================================================================

resource "aws_ecr_repository" "app" {
  name = var.name # "items-api"

  # MUTABLE lets a tag (e.g. :latest) be overwritten by a new push, which keeps
  # manual iteration smooth while learning.
  #   Production note: many teams use "IMMUTABLE" + a unique tag per build
  #   (e.g. the git commit SHA) so a tag ALWAYS points at the same image. We
  #   adopt SHA-based tags in the CI pipeline (Milestone 5).
  image_tag_mutability = "MUTABLE"

  # Security: scan every pushed image for known vulnerabilities (CVEs).
  image_scanning_configuration {
    scan_on_push = true
  }

  # Convenience for this ephemeral project: allows `terraform destroy` to delete
  # the repo even if it still contains images.
  #   Production note: you'd leave this OFF, so you can't accidentally wipe your
  #   image history with one command.
  force_delete = true

  tags = { Name = "${var.name}-ecr" }
}

# Lifecycle policy keeps the registry from growing forever (ECR bills for stored
# image data). It runs automatically on ECR's side.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the 10 most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
