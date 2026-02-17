<video src="assets/videos/demo.mp4" autoplay muted loop playsinline controls width="100%"></video>

## Project Overview

This repository contains a multi-container Todo application and infrastructure automation for deployment on AWS EC2.

The application consists of:
- A React frontend served by Nginx
- A FastAPI backend
- A PostgreSQL database

Infrastructure and deployment are automated with:
- Terraform (networking, EC2, ECR, IAM, OIDC trust)
- GitHub Actions (build, push, and remote deploy)

The default deployment model is a single EC2 host running Docker Compose.

## Architecture

The deployed runtime uses one EC2 instance with Docker Compose managing three services: `frontend`, `backend`, and `db`.

Request and data flow:
1. A user opens the frontend on port `3000` (`frontend` container, Nginx).
2. Browser requests to `/api/*` are handled by Nginx and proxied to `http://backend:8000/api/*` using Docker Compose service discovery.
3. The backend (`FastAPI`) processes API requests and connects to PostgreSQL using `DB_*` environment variables.
4. PostgreSQL (`db`) persists data on a named Docker volume (`postgres_data`).

Image and deploy flow:
1. On push to `main`, GitHub Actions assumes an AWS IAM role via OIDC (`sts:AssumeRoleWithWebIdentity`).
2. The workflow builds backend and frontend images, tags both with the commit SHA, and pushes to ECR.
3. The workflow connects to EC2 via SSH, ensures deployment files exist, updates environment values, and runs:
   - `docker compose -f $APP_DIR/docker-compose.yml pull`
   - `docker compose -f $APP_DIR/docker-compose.yml up -d --remove-orphans`

Health and logging:
- `db`, `backend`, and `frontend` each define container health checks in Compose.
- All services use `json-file` Docker logging with rotation (`max-size: 10m`, `max-file: 3`).

## Tech Stack

- Frontend: React 19, TypeScript, Vite, Nginx
- Backend: Python 3.11, FastAPI, SQLAlchemy, psycopg2
- Database: PostgreSQL 16 (Alpine image)
- Container runtime: Docker + Docker Compose
- CI/CD: GitHub Actions
- Cloud: AWS EC2, ECR, IAM, OIDC
- Infrastructure as Code: Terraform

## Prerequisites

Local tooling:
- Git
- Docker and Docker Compose
- Terraform >= 1.5
- AWS CLI (for infrastructure operations)

AWS requirements:
- AWS account with permissions to create VPC, EC2, ECR, IAM resources
- Existing GitHub repository connected to this codebase

GitHub requirements:
- Repository Secrets and Variables configured (see Environment Variables)

## Local Development Setup

1. Clone repository:

```bash
git clone <your-repo-url>
cd composed-app-on-ec2
```

2. Create a root `.env` for Compose local runtime:

```bash
cat > .env <<'EOF'
POSTGRES_DB=todo_db
POSTGRES_USER=todo_user
POSTGRES_PASSWORD=todo_password
DB_USER=todo_user
DB_PASSWORD=todo_password
DB_HOST=db
DB_PORT=5432
DB_NAME=todo_db
BACKEND_IMAGE=todo-backend
BACKEND_TAG=latest
FRONTEND_IMAGE=todo-frontend
FRONTEND_TAG=latest
AWS_REGION=eu-west-1
EOF
```

3. Start local stack:

```bash
docker compose up --build
```

4. Access services:
- Frontend: `http://localhost:3000`
- Backend direct: `http://localhost:8000`

5. Stop stack:

```bash
docker compose down
```

For infrastructure provisioning:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

## Environment Variables

### Application Runtime Variables (used by Docker Compose on EC2 and locally)

| Name | Purpose | Required | Source | Default/Fallback |
|---|---|---|---|---|
| `POSTGRES_DB` | PostgreSQL database name for `db` container | Yes | GitHub Secret (deploy), local `.env` (local dev) | None |
| `POSTGRES_USER` | PostgreSQL username for `db` container | Yes | GitHub Secret (deploy), local `.env` | None |
| `POSTGRES_PASSWORD` | PostgreSQL password for `db` container | Yes | GitHub Secret (deploy), local `.env` | None |
| `DB_USER` | Backend DB username | Yes | Derived from `POSTGRES_USER` in deploy script, or local `.env` | None |
| `DB_PASSWORD` | Backend DB password | Yes | Derived from `POSTGRES_PASSWORD` in deploy script, or local `.env` | None |
| `DB_HOST` | Backend DB host | Yes | GitHub Variable (`DB_HOST`) in deploy, local `.env` | `db` in deploy script fallback |
| `DB_PORT` | Backend DB port | Yes | GitHub Variable (`DB_PORT`) in deploy, local `.env` | `5432` in deploy script fallback |
| `DB_NAME` | Backend DB name | Yes | Derived from `POSTGRES_DB` in deploy script, or local `.env` | None |
| `BACKEND_IMAGE` | Backend image repository URI | Yes | GitHub Variable (`ECR_BACKEND_REPO`) mapped in workflow | `todo-backend` in compose interpolation |
| `BACKEND_TAG` | Backend image tag to deploy | Yes | `github.sha` in workflow | `latest` in compose interpolation |
| `FRONTEND_IMAGE` | Frontend image repository URI | Yes | GitHub Variable (`ECR_FRONTEND_REPO`) mapped in workflow | `todo-frontend` in compose interpolation |
| `FRONTEND_TAG` | Frontend image tag to deploy | Yes | `github.sha` in workflow | `latest` in compose interpolation |
| `AWS_REGION` | AWS region used by deploy script | Yes | GitHub Variable (`AWS_REGION`) | None |

### Frontend Build-Time Variable (Vite)

| Name | Purpose | Required | Source | Default/Fallback |
|---|---|---|---|---|
| `VITE_API_URL` | API base URL compiled into frontend bundle at image build | Optional | GitHub Variable (`VITE_API_URL`) passed as Docker build arg | `/api` |

Notes:
- `VITE_API_URL` is resolved at frontend image build time, not container runtime.
- With current Nginx config, `/api` is recommended and proxied to backend service.

### GitHub Actions Repository Variables

| Name | Purpose | Required | Source |
|---|---|---|---|
| `AWS_REGION` | Region for AWS auth and ECR login | Yes | GitHub Actions variable |
| `ECR_BACKEND_REPO` | Full backend ECR repo URI | Yes | GitHub Actions variable |
| `ECR_FRONTEND_REPO` | Full frontend ECR repo URI | Yes | GitHub Actions variable |
| `EC2_APP_DIR` | Remote deploy directory on EC2 | Yes | GitHub Actions variable |
| `VITE_API_URL` | Frontend API URL build arg | Optional | GitHub Actions variable |
| `DB_HOST` | Backend DB host runtime value | Optional | GitHub Actions variable |
| `DB_PORT` | Backend DB port runtime value | Optional | GitHub Actions variable |

### GitHub Actions Repository Secrets

| Name | Purpose | Required | Source |
|---|---|---|---|
| `AWS_ROLE_ARN` | IAM role assumed via OIDC by workflow | Yes | GitHub Actions secret |
| `EC2_HOST` | Public host/IP for SSH deploy | Yes | GitHub Actions secret |
| `EC2_USER` | SSH username on EC2 | Yes | GitHub Actions secret |
| `EC2_SSH_PRIVATE_KEY` | Private key for SSH/SCP actions | Yes | GitHub Actions secret |
| `POSTGRES_DB` | Runtime DB name injected into remote `.env` | Yes | GitHub Actions secret |
| `POSTGRES_USER` | Runtime DB user injected into remote `.env` | Yes | GitHub Actions secret |
| `POSTGRES_PASSWORD` | Runtime DB password injected into remote `.env` | Yes | GitHub Actions secret |

### Terraform Input Variables (`terraform/variables.tf`)

These are configuration variables for infrastructure provisioning and are typically populated through `terraform/terraform.tfvars`.

| Name | Purpose | Required | Source | Default |
|---|---|---|---|---|
| `aws_region` | AWS provider region | No | tfvars | `us-east-1` |
| `project_name` | Resource name prefix | No | tfvars | `composed-app` |
| `environment` | Environment identifier | No | tfvars | `dev` |
| `vpc_cidr` | VPC CIDR | No | tfvars | `10.0.0.0/16` |
| `availability_zones` | VPC AZ list | Yes | tfvars | None |
| `public_subnet_cidrs` | Public subnet CIDRs | Yes | tfvars | None |
| `instance_type` | EC2 instance type | No | tfvars | `t3.micro` |
| `ec2_ami_id` | AMI override | No | tfvars | empty (uses SSM latest AL2) |
| `ec2_key_name` | EC2 key pair name | Yes | tfvars | None |
| `ec2_public_key_path` | Local public key path used to create key pair in AWS | Yes | tfvars | None |
| `allowed_ssh_cidr` | CIDR allowed for SSH ingress | No | tfvars | `0.0.0.0/0` |
| `backend_ecr_repo_name` | Backend ECR repository name | No | tfvars | `todo-backend` |
| `frontend_ecr_repo_name` | Frontend ECR repository name | No | tfvars | `todo-frontend` |
| `github_repository` | GitHub repo for OIDC trust condition | Yes | tfvars | None |
| `github_branch` | Branch allowed in OIDC trust condition | No | tfvars | `main` |
| `app_dir` | Remote app directory on EC2 | No | tfvars | `/opt/composed-app-on-ec2` |
| `tags` | Additional AWS tags | No | tfvars | `{}` |

## Deployment

The deployment pipeline is implemented in `.github/workflows/deploy.yml` and triggers on pushes to `main`.

### CI/CD flow

1. **OIDC authentication to AWS**
   - Workflow requests a GitHub OIDC token.
   - `aws-actions/configure-aws-credentials@v4` assumes IAM role from `AWS_ROLE_ARN`.
   - IAM trust is restricted with:
     - `aud = sts.amazonaws.com`
     - `sub` matching repository + branch/environment patterns.

2. **Image build and push to ECR**
   - Backend image: `ECR_BACKEND_REPO:${GITHUB_SHA}`
   - Frontend image: `ECR_FRONTEND_REPO:${GITHUB_SHA}`
   - Frontend build receives `VITE_API_URL` via Docker build arg.

3. **Remote deploy on EC2**
   - SSH creates and owns `EC2_APP_DIR`.
   - SCP uploads `docker-compose.yml` into that directory.
   - SSH script logs into ECR and updates `EC2_APP_DIR/.env` with:
     - image URIs and tags
     - DB runtime values from GitHub Secrets/Variables
   - Compose executes:

```bash
docker compose -f "$APP_DIR/docker-compose.yml" pull backend frontend
docker compose -f "$APP_DIR/docker-compose.yml" up -d --remove-orphans
```

### Terraform deployment responsibilities

Terraform provisions:
- VPC and public subnets
- Security group rules for SSH and app ports
- EC2 instance and IAM instance profile
- ECR repositories and lifecycle policies
- IAM role and policy for GitHub Actions OIDC push access
- EC2 IAM role permissions for ECR pull

Terraform outputs required by CI setup include:
- ECR repository URLs
- OIDC role ARN
- EC2 public IP/DNS
- app directory path

## Contributing

1. Create a feature branch from `main`.
2. Keep changes scoped and aligned with existing structure.
3. Validate locally before opening a pull request:

```bash
docker compose config
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform validate
```

4. Include in the pull request:
- What changed
- Why it changed
- Operational impact (if any)

5. Do not commit secrets, private keys, or environment files containing credentials.

