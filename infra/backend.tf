# ---- Remote state backend ----
# State is stored in S3 (bucket: chu-statefile) instead of on your laptop, so
# it is durable and can be shared with the CI/CD pipeline later.
#
# use_lockfile = true uses S3's own conditional-write locking to stop two
# `terraform apply` runs from corrupting state at once. This replaced the older
# "separate DynamoDB lock table" approach, deprecated since Terraform 1.11.
#
# Note: backend blocks cannot use variables — the values must be literal.
# Terraform merges this terraform{} block with the one in versions.tf.
terraform {
  backend "s3" {
    bucket       = "chu-statefile"
    key          = "project-1/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
