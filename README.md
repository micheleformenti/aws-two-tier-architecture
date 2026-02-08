# AWS Two-Tier Architecture

This repository is a Terraform-first portfolio project that demonstrates AWS architecture and Infrastructure-as-Code implementation.

The Flask app is a minimal scope application (a tiny blog) used to exercise the infrastructure. The “product” here is the AWS design and Terraform implementation.

## What this showcases

- **Terraform module design** with environment wrappers (`dev`/`prod`) and a separate bootstrap for remote state.
- **Two-tier AWS architecture**: public edge + private compute + private database.
- **ECS Fargate in private subnets** behind an **internet-facing ALB**.
- **No NAT Gateway design**: private workloads reach AWS APIs via **VPC Endpoints (PrivateLink + S3 gateway endpoint)**.
- **Security fundamentals**: least-privilege security groups, encrypted RDS, Secrets Manager, TLS via ACM, Route 53 DNS.
- **Operational baseline**: CloudWatch logs, alarms (SNS email), dashboard widgets, ALB access logs to S3.
- **CI/CD-ready IAM**: GitHub Actions **OIDC role** to push images to ECR (no long-lived AWS keys).

## Architecture

High-level flow:

```
Internet
	|
	v
Route 53 (A/ALIAS)
	|
	v
ALB (public subnets)  :80 -> 301 -> :443 (ACM)
	|
	v
ECS Fargate service (private app subnets)
	|
	v
RDS PostgreSQL (private db subnets, Multi-AZ)
```

Key design choices:

- **Private compute, public entrypoint**: the ALB is public; ECS tasks do not have public IPs.
- **NAT-less private networking**: ECS tasks access ECR, CloudWatch Logs, Secrets Manager, STS, KMS via **Interface VPC Endpoints**, and S3 via a **Gateway VPC Endpoint**.
- **Tight egress** from the task security group: HTTPS to endpoints/S3, DNS to the VPC resolver, and PostgreSQL to RDS.
- **TLS by default**: HTTP redirects to HTTPS; ACM cert is DNS-validated in Route 53.

![NAT-less ECS Architecture](infra/ecs-architecture-natless.svg)

## What gets provisioned (Terraform)

The `two-tier-app` module builds:

- VPC, subnets across two AZs (public/app/db)
- Internet Gateway + public route table
- ALB (HTTP->HTTPS redirect, HTTPS listener, target group)
- Route 53 records + ACM certificate + DNS validation
- ECS Cluster + Task Definition + Service (Fargate) + autoscaling (CPU + memory)
- ECR repository (scan on push + lifecycle policy)
- RDS PostgreSQL instance (encrypted, Multi-AZ)
- Secrets Manager secrets (DB password + Flask `SECRET_KEY`)
- VPC Endpoints (ECR API/DKR, Logs, Secrets Manager, KMS, STS + S3 gateway)
- CloudWatch log group, optional alarms + SNS topic + dashboard
- Optional ALB access logs bucket (encrypted, versioned, blocked public access)
- IAM role for GitHub Actions to push images to ECR via OIDC

## Repository layout

```
app/                       # Reference Flask app (containerized)
	Dockerfile
	source/
		app.py
		requirements.txt
		templates/ static/

infra/
	bootstrap/               # S3 + DynamoDB for Terraform remote state
	environments/
		dev/                   # Environment wrapper around the module
		prod/
	modules/
		two-tier-app/          # Re-usable module that provisions the stack
```

## Prerequisites

- Terraform (tested with modern 1.x)
- AWS account + permissions to create VPC/ECS/ALB/RDS/IAM/Route53/ACM/etc.
- A Route 53 hosted zone you control (for ACM DNS validation + ALB alias record)
- A GitHub repository with GitHub Actions enabled (recommended path: build/push to ECR via OIDC)

Optional:

- Docker + AWS CLI if you prefer to build/push images manually from your workstation.

## Deploy (dev/prod)

### 1) (Recommended) Bootstrap remote state

This creates:

- S3 bucket for Terraform state (versioning + encryption + public access blocked)
- DynamoDB table for state locking

From `infra/bootstrap/`:

```bash
terraform init
terraform apply
```

Note: the bootstrap S3 bucket uses `prevent_destroy = true` on purpose.

### 2) Configure backend for an environment

From `infra/environments/dev/` (repeat similarly for `prod/`):

```bash
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` if you changed the bootstrap project/region, and ensure the `key` is unique per environment.

Then:

```bash
terraform init -backend-config=backend.hcl
```

### 3) Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Fill in at least:

- `github_org`, `github_repo` (for the GitHub OIDC role trust policy)
- `domain_name`, `route53_zone_name`
- `alarm_email` (you must confirm the SNS subscription email)

### 4) Build + push the app image to ECR (GitHub Actions + OIDC, recommended)

The module creates the ECR repository, but the ECS service needs an image URI. The recommended workflow is:

1) Create the ECR repo + GitHub OIDC role first (targeted apply)
2) Push an image from GitHub Actions (no long-lived AWS keys)
3) Set `ecr_image_uri` to the pushed tag and apply the full stack

From `infra/environments/dev/`:

```bash
# Create ECR + IAM role first
terraform apply \
	-target=module.app.aws_ecr_repository.app_repo \
	-target=module.app.aws_ecr_lifecycle_policy.app_repo_policy \
	-target=module.app.aws_iam_role.github_actions_ecr_role \
	-target=module.app.aws_iam_role_policy.github_actions_ecr_policy

# Capture outputs for your GitHub workflow
terraform output -raw ecr_repository_url
terraform output -raw github_actions_role_arn
```

This repository includes a workflow at `.github/workflows/ci.yml` that:

- Runs Ruff checks
- Builds the Docker image from `app/Dockerfile`
- On pushes to `main`, assumes the OIDC role and pushes to ECR

Configure these GitHub **Actions secrets**:

- `AWS_REGION` (e.g. `eu-central-1`)
- `AWS_ACCOUNT_ID` (12-digit account ID)
- `OIDC_ROLE_ARN` (Terraform output: `github_actions_role_arn`)
- `ECR_REPO` (the ECR repository name, typically `${project}-${env}`; e.g. `two-tier-app-dev`)

Then push to `main` (or run the workflow manually). The workflow publishes tags:

- `:main`
- `:sha-<git sha>`

Once an image tag exists in ECR, set `ecr_image_uri` in `terraform.tfvars` to something like:

`<account>.dkr.ecr.<region>.amazonaws.com/<repo>:main`

Then continue with the full apply.

### 4b) Build + push manually (optional)

If you want to push from your workstation instead of GitHub Actions:

```bash
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)

# Use the same region you configured in terraform.tfvars
AWS_REGION=eu-central-1

# Login to ECR
aws ecr get-login-password --region "$AWS_REGION" | \
	docker login --username AWS --password-stdin "${ECR_REPO_URL%/*}"

# Build and push
docker build -t "$ECR_REPO_URL:dev" ../../app
docker push "$ECR_REPO_URL:dev"
```

Then set `ecr_image_uri` in `terraform.tfvars` to `${ECR_REPO_URL}:dev`.

### 5) Apply the full stack

```bash
terraform apply
```

After it completes, Terraform outputs include:

- `alb_https_url` (the main entrypoint)
- `ecr_repository_url`
- `cloudwatch_log_group`
- `github_actions_role_arn`

Tip: `terraform output` shows the full list (some outputs like the RDS endpoint are marked sensitive).

## App behavior

The app is a small Flask + SQLAlchemy blog:

- On startup it creates the `posts` table if missing.
- In AWS, DB connection details are injected via environment variables and Secrets Manager.

This is intentionally minimal: no migrations, no auth, no advanced features.

## Security & ops notes

- **RDS is private** (`publicly_accessible = false`) and encrypted at rest.
- **Secrets** are generated and stored in Secrets Manager.
- **ECS tasks have no public IPs**, and are reachable only via the ALB.
- **CloudWatch**: logs are shipped to a log group with retention; alarms and a dashboard can be toggled via variables.
- **ALB access logs** are stored in S3 (encrypted + versioned + public access blocked).

## Destroy / cleanup

From the environment folder (e.g. `infra/environments/dev/`):

```bash
terraform destroy
```

Bootstrap resources (state bucket + lock table) are intentionally long-lived. If you truly want to remove them, you must first remove/adjust `prevent_destroy` in `infra/bootstrap/backend.tf`.

## Cost warning

This stack can incur real AWS costs (ALB, Fargate tasks, RDS Multi-AZ, VPC Interface Endpoints, CloudWatch, S3 logs). Use small instance sizes for demos and destroy when done.