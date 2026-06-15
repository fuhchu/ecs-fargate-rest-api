# Teardown / Cleanup Log

Every AWS resource this project creates is logged here so nothing gets
orphaned. When you're done, remove everything to stop all charges.

**Account:** 445481011516 &nbsp;|&nbsp; **Region:** us-west-2

---

## Order of teardown

1. `cd infra && terraform destroy` — removes everything Terraform manages.
2. Then delete the bootstrap state bucket by hand (it holds Terraform's own
   state, so it must go LAST).

---

## Bootstrapped manually (outside Terraform)

- [ ] **S3 bucket:** `chu-statefile` — Terraform remote state. Must be emptied
  (all object versions) before it can be deleted; do this LAST.
- [ ] **DynamoDB table:** `chu-locktable` — created but **unused** (we chose
  S3-native locking). Safe to delete any time:
  ```powershell
  aws dynamodb delete-table --table-name chu-locktable
  ```

## Terraform-managed (removed by `terraform destroy`)

Run `cd infra && terraform destroy` to remove ALL of the below in one command.

- **VPC networking** (Milestone 3d): VPC, 2 public + 2 private subnets, Internet
  Gateway, **2 NAT Gateways + 2 Elastic IPs** (the costed pieces, ~$2/day),
  route tables and associations.
  - 💰 **Destroy this between sessions** — NAT Gateways bill hourly whether or
    not traffic flows.
- **ECR repository** (Milestone 3e): `items-api` repo + lifecycle policy.
  `force_delete = true`, so `terraform destroy` removes it even with images
  inside. Storage cost is negligible.
- **IAM roles + CloudWatch log group** (Milestone 4a): task-execution role,
  task role, `/ecs/items-api` log group. No standing cost.
- **Security groups + ALB** (Milestone 4b): ALB + task security groups, the
  Application Load Balancer, target group, listener.
  - 💰 The **ALB bills ~$0.55/day** while it exists. Included in `terraform destroy`.
- **ECS cluster/service/tasks** (Milestone 4c): cluster, task definition,
  service running 2 Fargate tasks.
  - 💰 2 Fargate tasks bill ~$0.60/day. Included in `terraform destroy`.
