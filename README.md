# FrontandBack — Production-Grade AWS Deployment Platform

A production-grade deployment platform built on AWS for two containerized services — a React frontend and an Express.js backend. The platform demonstrates enterprise DevOps practices including infrastructure as code, blue/green deployments, zero-downtime releases, and automated CI/CD pipelines.

**Live URL:** http://app-alb-1750369817.us-east-1.elb.amazonaws.com

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Infrastructure Modules](#infrastructure-modules)
- [Application](#application)
- [CI/CD Pipeline](#cicd-pipeline)
- [Blue/Green Deployment Strategy](#bluegreen-deployment-strategy)
- [Security](#security)
- [Prerequisites](#prerequisites)
- [Deploying From Scratch](#deploying-from-scratch)
- [Running Locally](#running-locally)
- [Roadmap](#roadmap)

---

## Overview

This platform packages both services as Docker containers, stores them in Amazon ECR, and deploys them on ECS Fargate behind an Application Load Balancer. All infrastructure is defined in Terraform — the entire environment can be torn down and recreated from scratch with a single command.

### The Deployment Process

1. Docker images are built for the frontend and backend
2. Images are pushed to ECR, tagged with the Git commit SHA for full traceability
3. New ECS task definitions are registered pointing to the updated images
4. The new version is deployed to the inactive ("green") environment
5. A validation step confirms the new version is healthy — tasks running, health endpoints responding, no errors
6. Traffic shifts from the live ("blue") environment to the newly validated ("green") environment
7. If any step fails, the deployment automatically rolls back — the blue environment continues serving traffic uninterrupted

This ensures **safe, repeatable, zero-downtime deployments** on every push to `main`.

---

## Architecture

```
                        ┌─────────────────────────────────┐
                        │         Internet (0.0.0.0/0)    │
                        └────────────────┬────────────────┘
                                         │
                        ┌────────────────▼────────────────┐
                        │   Application Load Balancer      │
                        │   (Public Subnets — port 80)     │
                        └──────┬─────────────────┬─────────┘
                               │                 │
                    Default /  │                 │  /api/*
                               │                 │
              ┌────────────────▼──┐         ┌────▼──────────────┐
              │  Frontend Service │         │  Backend Service   │
              │  (port 3000)      │         │  (port 8080)       │
              │                   │         │                    │
              │  ┌─────────────┐  │         │  ┌─────────────┐  │
              │  │frontend-blue│  │         │  │backend-blue │  │
              │  └─────────────┘  │         │  └─────────────┘  │
              │  ┌─────────────┐  │         │  ┌─────────────┐  │
              │  │frontend-green│ │         │  │backend-green│  │
              │  └─────────────┘  │         │  └─────────────┘  │
              └───────────────────┘         └────────────────────┘
                        │                            │
              ┌─────────▼────────────────────────────▼──────────┐
              │              Private Subnets                      │
              │         ECS Fargate (us-east-1a, us-east-1b)     │
              └───────────────────────┬──────────────────────────┘
                                      │
                        ┌─────────────▼────────────┐
                        │        NAT Gateway        │
                        │   (ECR image pulls,       │
                        │    CloudWatch logs)        │
                        └──────────────────────────-┘
```

### Networking
- **VPC CIDR:** `10.0.0.0/16`
- **Public Subnets:** `10.0.0.0/20`, `10.0.16.0/20` — ALB placement across `us-east-1a` and `us-east-1b`
- **Private Subnets:** `10.0.32.0/20`, `10.0.48.0/20` — ECS task placement across `us-east-1a` and `us-east-1b`
- **Internet Gateway** — public subnet egress
- **NAT Gateway** — private subnet egress (image pulls, log shipping)

### Load Balancing
- Single ALB with path-based routing
- `/api/*` routes to the backend target group
- All other traffic routes to the frontend target group
- Separate blue and green target groups per service for traffic switching

### Compute
- ECS Fargate — serverless container runtime, no EC2 instances to manage
- Each service runs as 1 task (scalable via `desired_count`)
- 256 CPU units / 512 MB memory per task

---

## Project Structure

```
FrontandBack/
├── frontend/                        # React application
│   ├── src/
│   │   ├── App.js                   # Main component
│   │   ├── App.css                  # Styles
│   │   └── config.js                # Backend URL configuration
│   └── Dockerfile                   # Multi-stage build
│
├── backend/                         # Express.js API
│   ├── index.js                     # Server entry point
│   ├── config.js                    # CORS configuration
│   └── Dockerfile
│
├── infra/
│   ├── envs/
│   │   ├── dev/
│   │   │   ├── main.tf              # Dev environment resources
│   │   │   └── github-oidc.tf       # GitHub Actions IAM role
│   │   └── prod/
│   │       └── main.tf              # Prod environment (+ monitoring)
│   │
│   ├── modules/
│   │   ├── vpc/                     # VPC, subnets, IGW, NAT, route tables
│   │   ├── ecr/                     # ECR repository
│   │   ├── alb/                     # ALB, target groups, listener rules
│   │   ├── ecs-cluster/             # ECS cluster, task execution IAM role
│   │   ├── ecs-service/             # ECS task definition and service
│   │   ├── prometheus/              # Prometheus on ECS (prod only)
│   │   └── grafana/                 # Grafana on ECS (prod only)
│   │
│   └── task-definitions/
│       ├── frontend.json            # Frontend task definition template
│       └── backend.json             # Backend task definition template
│
└── .github/
    └── workflows/
        └── deploy-dev.yml           # CI/CD pipeline
```

---

## Infrastructure Modules

### `vpc`
Provisions the full networking layer: VPC, public and private subnets across two availability zones, Internet Gateway, NAT Gateway, and route tables. ECS tasks run in private subnets with no public IPs — all inbound traffic arrives via the ALB.

### `ecr`
Creates an Elastic Container Registry repository. Instantiated once for frontend and once for backend.

### `alb`
Provisions the Application Load Balancer, all four target groups (frontend-blue, frontend-green, backend-blue, backend-green), the HTTP listener, and the `/api/*` path-based routing rule. Listener rules use `ignore_changes` in Terraform so the CI/CD pipeline can control traffic switching without Terraform reverting the state.

### `ecs-cluster`
Creates the ECS cluster and the `ecsTaskExecutionRole` IAM role used by all tasks to pull images from ECR and write logs to CloudWatch.

### `ecs-service`
Creates an ECS task definition and service. Supports optional load balancer attachment for blue services and environment variable injection. Used by all four application services (frontend-blue, frontend-green, backend-blue, backend-green).

### `prometheus` _(prod only)_
Runs Prometheus on ECS Fargate with an EFS volume for persistent storage. Scrapes CloudWatch metrics and ECS task metadata. Retention: 14 days.

### `grafana` _(prod only)_
Runs Grafana on ECS Fargate pre-configured with Prometheus as a datasource for infrastructure dashboards.

---

## Application

### Frontend
React application served on port 3000. The backend URL is injected at Docker build time via `REACT_APP_BACKEND_URL` — because React builds to static files, the backend URL must be known at build time, not runtime.

### Backend
Express.js API on port 8080 with two endpoints:

| Endpoint | Description |
|---|---|
| `GET /health` | Health check used by ALB target groups |
| `GET /api/*` | Returns a UUID — used to verify backend connectivity |

CORS is configured via the `CORS_ORIGIN` environment variable, set dynamically to the ALB DNS at deployment time.

---

## CI/CD Pipeline

Every push to `main` triggers an automated deployment via GitHub Actions.

```
Push to main
    │
    ├── Authenticate to AWS via GitHub OIDC (no stored credentials)
    ├── Retrieve ALB DNS name
    │
    ├── Build frontend image  (ALB DNS baked in via build arg)
    ├── Build backend image
    ├── Push both images to ECR  (tagged with Git commit SHA)
    │
    ├── Prepare frontend task definition  (replace IMAGE_TAG placeholder)
    ├── Register frontend task definition with ECS
    │
    ├── Prepare backend task definition  (replace IMAGE_TAG + ALB_DNS placeholders)
    ├── Register backend task definition with ECS
    │
    ├── Deploy frontend → frontend-green service
    ├── Deploy backend  → backend-green service
    │
    ├── Wait for both green services to stabilize (health checks passing)
    │
    ├── Switch ALB default action  →  frontend-green target group
    └── Switch ALB /api/* rule     →  backend-green target group
```

### GitHub Secrets Required

| Secret | Description |
|---|---|
| `ALB_LISTENER_ARN` | ARN of the ALB HTTP listener |
| `GREEN_TG_ARN` | ARN of the frontend-green target group |
| `BACKEND_LISTENER_RULE_ARN` | ARN of the `/api/*` listener rule |
| `BACKEND_GREEN_TG_ARN` | ARN of the backend-green target group |

---

## Blue/Green Deployment Strategy

Two identical environments — blue and green — run in parallel at all times.

| Environment | Role |
|---|---|
| **Blue** | Currently serving live traffic |
| **Green** | Receives the new deployment |

The pipeline deploys to green, waits for it to pass health checks, then switches the ALB to send traffic to green. If the deployment fails at any point, blue continues serving traffic uninterrupted.

This approach eliminates deployment downtime and provides an instant rollback path — simply switch the ALB back to the blue target group.

---

## Security

- **No public IPs on ECS tasks** — all traffic flows through the ALB
- **Security groups** — ECS tasks only accept traffic from the ALB security group on the container ports (3000 and 8080)
- **GitHub OIDC** — GitHub Actions assumes an IAM role via OpenID Connect; no long-lived access keys are stored anywhere
- **Least privilege IAM** — the `github-oidc-role` is scoped to only the permissions required by the pipeline (ECR push, ECS update, ALB modify)
- **Repository scoping** — the OIDC trust policy restricts which GitHub repository can assume the role

---

## Prerequisites

| Tool | Purpose |
|---|---|
| [Terraform >= 1.0](https://developer.hashicorp.com/terraform/install) | Infrastructure provisioning |
| [AWS CLI](https://aws.amazon.com/cli/) | Interacting with AWS |
| [Docker](https://www.docker.com/get-started/) | Building container images |
| Git | Source control |

An AWS account with sufficient permissions to create VPCs, ECS clusters, ALBs, ECR repositories, and IAM roles is required.

---

## Deploying From Scratch

### 1. Deploy Infrastructure

```bash
cd infra/envs/dev
terraform init
terraform apply
```

### 2. Authenticate Docker to ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

### 3. Get the ALB DNS

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names app-alb \
  --query "LoadBalancers[0].DNSName" \
  --output text --region us-east-1)
echo $ALB_DNS
```

### 4. Build and Push Initial Images

```bash
# Backend
docker build -t backend ./backend
docker tag backend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/backend:v1
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/backend:v1

# Frontend (ALB DNS is baked in at build time)
docker build --build-arg REACT_APP_BACKEND_URL=http://$ALB_DNS -t frontend ./frontend
docker tag frontend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/frontend:v1
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/frontend:v1
```

### 5. Start the Initial Services

```bash
aws ecs update-service --cluster dev-cluster \
  --service frontend-blue --force-new-deployment --region us-east-1

aws ecs update-service --cluster dev-cluster \
  --service backend-blue --force-new-deployment --region us-east-1
```

### 6. Configure GitHub Secrets

Add the following secrets to your GitHub repository under **Settings → Secrets and variables → Actions**:

```bash
# ALB Listener ARN
aws elbv2 describe-listeners \
  --load-balancer-arn $(aws elbv2 describe-load-balancers \
    --names app-alb --query "LoadBalancers[0].LoadBalancerArn" \
    --output text --region us-east-1) \
  --query "Listeners[0].ListenerArn" --output text --region us-east-1

# Frontend Green Target Group ARN
aws elbv2 describe-target-groups \
  --names frontend-green-tg \
  --query "TargetGroups[0].TargetGroupArn" --output text --region us-east-1

# Backend Listener Rule ARN (the /api/* rule)
aws elbv2 describe-rules \
  --listener-arn <listener-arn> --region us-east-1

# Backend Green Target Group ARN
aws elbv2 describe-target-groups \
  --names backend-green-tg \
  --query "TargetGroups[0].TargetGroupArn" --output text --region us-east-1
```

### 7. Subsequent Deployments

Push any change to `main` — the pipeline handles everything automatically.

---

## Running Locally

```bash
# Start backend
cd backend
npm ci
npm start
# Listening on http://localhost:8080

# Start frontend (separate terminal)
cd frontend
npm ci
npm start
# Listening on http://localhost:3000
```

Or with Docker Compose:

```bash
docker-compose up --build
```

---

## Roadmap

- [ ] Upgrade to AWS CodeDeploy for automated traffic shifting and rollback
- [ ] Python validation script for pre-traffic health checks
- [ ] Production environment deployment
- [ ] Prometheus & Grafana monitoring (prod)
- [ ] HTTPS / SSL via ACM
