# Containerized REST API on AWS ECS Fargate

A production-style REST API (Python / FastAPI) containerized with Docker and
deployed to **AWS ECS Fargate** behind an **Application Load Balancer**.
Infrastructure is defined in **Terraform**; every push to `main` runs a
**GitHub Actions** pipeline that tests, builds, pushes to ECR, and deploys.

> Project 1 of a 4-part DevOps portfolio. This one deliberately covers every
> layer — code, container, infrastructure, pipeline — for a single service,
> before later projects scale out to microservices and Kubernetes.

## Architecture

```
GitHub  →  GitHub Actions (CI/CD)  →  Amazon ECR  →  ECS Fargate  →  ALB  →  users
```

📖 **Full deep-dive:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — end-to-end
request flow, every layer explained, diagrams, cost breakdown, and design tradeoffs.

## Tech stack

| Layer | Choice |
|-------|--------|
| Language / framework | Python, FastAPI |
| Container | Docker |
| Registry | Amazon ECR |
| Compute | AWS ECS Fargate |
| Networking | VPC, public/private subnets, Application Load Balancer |
| Infrastructure as code | Terraform (S3 remote state) |
| CI/CD | GitHub Actions |
| Logs | Amazon CloudWatch |

## Run locally

```bash
# 1. Create and populate an isolated environment
python -m venv .venv
.venv\Scripts\Activate.ps1          # Windows PowerShell
pip install -r requirements-dev.txt

# 2. Run the test suite
pytest

# 3. Start the API (http://127.0.0.1:8000, docs at /docs)
uvicorn app.main:app --reload
```

## API endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Health check used by the load balancer |
| GET | `/` | Service identity / smoke test |
| GET | `/items` | List items |
| POST | `/items` | Create an item |
| GET | `/items/{id}` | Fetch one item |

## Project status

- [x] Milestone 0 — Repo foundation
- [x] Milestone 1 — API + tests
- [x] Milestone 2 — Dockerfile
- [x] Milestone 3 — Terraform: state, VPC, ECR
- [x] Milestone 4 — Terraform: ECS, ALB, IAM
- [ ] Milestone 5 — CI/CD pipeline
- [ ] Milestone 6 — Polish: rollback, diagram, interview notes
