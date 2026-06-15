# AWS provider configuration: which region to deploy into, and tags that get
# stamped onto every resource automatically.

provider "aws" {
  region = var.aws_region

  # default_tags applies these tags to EVERY resource created by this provider.
  # Why it matters:
  #   - Cost tracking: you can see spend grouped by Project.
  #   - Cleanup: when you're done, you can find and delete everything tagged
  #     Project=items-api with confidence that nothing is left behind.
  default_tags {
    tags = {
      Project   = "items-api"
      ManagedBy = "Terraform"
    }
  }
}
