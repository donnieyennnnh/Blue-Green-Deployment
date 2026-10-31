# Blue-Green Deployment Pipeline

> Zero-downtime CI/CD pipeline on AWS. One `git push` to deploy and one click to roll back.

This project is to have a automated server deployment through using the CICD pipeline which uses Infrastructure-as-Code, configuration management, containers, zero-downtime deployment, observability and Blue green deployment with security practises

## TL;DR

- **Infra:** Terraform provisions a single EC2 + VPC in AWS `ap-southeast-1`
- **Config:** Ansible hardens SSH, installs Docker/Nginx, UFW, fail2ban
- **App:** Dockerised Node.js Express app ("Bob Ross gallery") with health + Prometheus metrics endpoints
- **CI:** GitHub Actions runs lint + tests + builds the image to GHCR
- **CD:** GitHub Actions SSHes to the EC2 and runs a blue-green deploy — new container boots, health-checks, Nginx upstream flips, old container stays as rollback
- **Rollback:** one-click manual GitHub Actions workflow flips Nginx back; takes under 1 second
- **Monitoring:** Prometheus + Grafana + node_exporter stack with a provisioned dashboard and alert rule, accessed via SSH tunnel
- **Security:** GitHub OIDC federation (no stored AWS keys), least-privilege IAM, ephemeral SG rules opened per-deploy, non-root containers, SSH key-only auth

**Full architecture:** [docs/architecture.md](docs/architecture.md) · **Troubleshooting:** [docs/troubleshooting.md](docs/troubleshooting.md)


## Architecture at a glance

```
Developer ─push──▶ GitHub ─CI─▶ GHCR
                     │
                     └─CD (OIDC) ─▶ EC2 ap-southeast-1
                                       │
                                       ├─ Nginx :80 ──▶ blue  :3001
                                       │               └▶ green :3002  (one active, one standby)
                                       │
                                       ├─ Prometheus + Grafana + node_exporter (via SSH tunnel)
                                       └─ UFW + fail2ban + hardened sshd
```

Full Mermaid diagram with sequence flow in [docs/architecture.md](docs/architecture.md).

## Repository layout

```
app/                    Node.js Express app + Dockerfile          
terraform/              AWS VPC, EC2, SG, key pair, outputs       
ansible/                Playbook: hardening, Docker, Nginx        
deploy/                 deploy.sh + rollback.sh                   
monitoring/             Prometheus + Grafana + node_exporter      
.github/workflows/      ci.yml (test + build + deploy)            
                        rollback.yml (manual trigger)
docs/                   architecture.md, troubleshooting.md       
```

## Running the app locally (without AWS)

For dev work without touching AWS:

```powershell
cd app
docker compose up --build
# http://localhost:3000
```

Or with Node directly:

```powershell
cd app
npm install
npm run dev    # auto-restarts on file change
```

Both work independently of the production stack.

## Tearing it down

Costs stop the moment you destroy:

```powershell
cd terraform
terraform destroy
```

Local state file + SSH keys stay on your machine. Next session, `terraform apply` recreates everything in ~60 seconds with a new public IP.

## Problems I hit and how I solved them

Real debugging journey captured in [docs/troubleshooting.md](docs/troubleshooting.md). Highlights:

- **Terraform:** Asked AWS for a specific Ubuntu image by name, but the name was slightly different in the Singapore region than elsewhere. Fixed by using a wildcard so any matching name works
- **Ansible:** Ubuntu's Singapore software mirror kept serving corrupted data mid-install. Switched to the main global mirror. Also had to turn on an extra package list before `fail2ban` could be found
- **GitHub OIDC:** AWS kept rejecting the token even with a seemingly correct trust policy. Discovered via CloudTrail that GitHub was sending the new immutable-subject format with internal numeric IDs (`repo:owner@12345/repo@67890:...`), not the classic `repo:owner/repo:...`
- **Monitoring:** Prometheus couldn't scrape the app containers — spent time understanding Docker networking before realizing the containers bound to `127.0.0.1` on the host weren't reachable from Prometheus's own private network. Solution: `network_mode: host` for all three monitoring containers

## Future improvements

Documented but intentionally not implemented to keep scope bounded:
- **ECR instead of GHCR** — AWS-native registry, standard choice at job
- **AWS Systems Manager Session Manager** — eliminates the SSH key secret entirely
- **S3 remote Terraform state** — needed if more than one person works on this
- **AWS Certificate Manager + HTTPS on Nginx** — Let's Encrypt or ACM
- **Alertmanager + Slack/email notifications** — alerts currently show in the Prometheus UI only
- **Multi-AZ with a load balancer** — for production, swap the single EC2 for an ALB + multi-AZ Auto Scaling Group
- **Kubernetes** — the "right" scale answer; demonstrated manually here to make the mechanics explicit

## Why this stack

- **Chose single-EC2 + manual blue-green instead of Kubernetes/ECS** to demonstrate deployment mechanics without the orchestrator hiding them. Production would use ECS or K8s rolling updates; the understanding translates directly
- **Chose GHCR over ECR** — zero AWS setup for registry auth, free for public images, authenticated via the built-in `GITHUB_TOKEN`
- **Chose OIDC federation over long-lived AWS keys** — eliminates the "keys leaked from GitHub secrets" risk entirely
- **Chose Nginx config swap over an application load balancer** — $20/month saved and the pattern is easier to debug when something breaks

## License

MIT — do whatever you want with it; it's a portfolio artifact.
