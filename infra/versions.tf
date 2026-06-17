# Terraform settings: required CLI version and providers.
# (The remote-state backend lives in its own file: backend.tf)

terraform {
  # use_lockfile (S3-native state locking) requires Terraform >= 1.10.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Used to fetch GitHub's OIDC certificate fingerprint dynamically, so we
    # never hardcode a thumbprint that could change.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
