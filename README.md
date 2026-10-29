# Blue-Green Deployment Pipeline

> A zero-downtime CI/CD pipeline on AWS. One `terraform apply` to provision, one `git push` to deploy, one script to roll back. Monitored by Prometheus + Grafana.

## Why this project exists

This is a learning / portfolio project. It stitches together the tools a modern DevOps role expects you to know — IaC, config management, containerization, CI/CD, zero-downtime deployment, observability — into one end-to-end story on real cloud infrastructure.

## Status

Built in phases, one at a time. Current phase is checked.

- [x] **Phase 0** — Prerequisites + repo scaffold
- [ ] **Phase 1** — Node.js Express app + Dockerfile
- [ ] **Phase 2** — Terraform: AWS VPC + single EC2 + firewall + SSH key
- [ ] **Phase 3** — Ansible: SSH hardening, UFW, fail2ban, Docker, Nginx
- [ ] **Phase 4** — GitHub Actions CI: lint, test, build & push to GHCR
- [ ] **Phase 5** — GitHub Actions CD: SSH deploy to EC2
- [ ] **Phase 6** — Blue-green containers + Nginx switch + rollback script
- [ ] **Phase 7** — Prometheus + Grafana (dashboards as code, one alert)
- [ ] **Phase 8** — Polish: architecture diagram, screenshots, troubleshooting notes

## Architecture

Diagram will be added in Phase 8. In short:

```
GitHub ──push──▶ GitHub Actions ──build──▶ GHCR
                                            │
                                            ▼
                     ┌────────── EC2 (t3.micro) ──────────┐
                     │  Nginx  ──▶  app-blue  (:3000)     │
                     │          └▶  app-green (:3001)     │
                     │  Prometheus + Grafana + node_exp.  │
                     └────────────────────────────────────┘
```

Nginx picks one color as "live" via an upstream config file. Deploys target the inactive color, health-check, then flip the upstream and `nginx -s reload`. Rollback flips it back.

## Repository layout

```
app/                   Node.js Express app + Dockerfile          (Phase 1)
terraform/             AWS VPC, EC2, SG, key pair, outputs       (Phase 2)
ansible/               Playbooks: hardening, Docker, Nginx       (Phase 3)
deploy/                Blue-green switch + rollback scripts      (Phase 6)
monitoring/            Prometheus config, Grafana dashboards     (Phase 7)
.github/workflows/     CI (lint/test/build) + CD (deploy)        (Phases 4-5)
docs/                  Architecture diagram, troubleshooting     (Phase 8)
```

## Prerequisites

**You already have:** Git, Node.js 20+, npm, Docker Desktop, WSL2 (Ubuntu).

**You need to install before Phase 2:**

| Tool | What for | Install (PowerShell) |
|---|---|---|
| Terraform CLI | Phase 2 infra provisioning | `winget install HashiCorp.Terraform` |
| AWS CLI v2 | Credential config + debugging | `winget install Amazon.AWSCLI` |

**Verify both after install:**
```powershell
terraform -version
aws --version
```

Ansible (Phase 3) runs from WSL, not Windows. We'll install it inside WSL when we get there.

## Setup (one-time, done in Phase 0)

Before any infrastructure gets provisioned, do these in the AWS console:

1. **Set a Budget alert.** AWS Billing → Budgets → Create → "Zero spend budget" (notifies at $0.01) or "Monthly cost budget" at $10 with email alerts at 50%/80%/100%. This protects you from runaway costs. See the **AWS cost safety** section below.
2. **Create a dedicated IAM user for Terraform.** Never use root credentials with Terraform. See the **IAM user setup** section below.
3. **Copy `.env.example` to `.env`** and fill in values as you go. Phase 0 only needs `AWS_REGION` and `MY_IP_CIDR`.

Detailed walkthroughs are given at the end of Phase 0 in the chat; condensed versions will live here in Phase 8.

## Cost safety

Everything in this project is designed to be destroyed with `terraform destroy` in one command. The only AWS resource that costs money is the single EC2 instance.

Rough costs (us-east-1):
- t3.micro: **free** for 750 hr/month on new AWS accounts (12-month free tier); ~$0.0104/hr afterward
- EBS gp3 8 GB root volume: ~$0.64/month
- VPC, subnet, IGW, SG, key pair: **free**
- Data out: free tier gives 100 GB/month across all services

Expect **$0** during free-tier eligibility, **~$8/month** after.

> Note on container registry: this project uses **GHCR** (GitHub Container Registry) rather than AWS ECR. GHCR is free for public images and simpler to authenticate from GitHub Actions. ECR would be the AWS-native choice if you were running this at a job — mentioned here for completeness.

## Terraform state

State lives in `terraform/terraform.tfstate` locally. This is fine for a solo project. To move to remote state later:

1. Create an S3 bucket (versioning on) and a DynamoDB table (`LockID` as string PK) for state locking
2. Add a `backend "s3" {...}` block to `terraform/main.tf`
3. Run `terraform init -migrate-state`

Local state is gitignored (see `.gitignore`), so it never leaks to the repo.

## Secrets

Nothing sensitive is committed. The flow:

- `.env.example` — committed, lists every variable the project uses
- `.env` — gitignored, holds real values on your machine
- GitHub Actions Secrets — used by CI/CD workflows (set via repo Settings → Secrets)

Keys and tokens never appear in Terraform `.tf` files, Ansible playbooks, Dockerfiles, or workflow YAML.

## Running locally

Each phase adds its own "how to run" section. Phase 0 has nothing to run — only files to inspect.

## Problems I hit and how I solved them

(Written up as the project progresses — Phase 8 consolidates them.)

## License

MIT — do whatever you want with it; it's a portfolio artifact.
