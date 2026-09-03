# AWS ECS Fargate CI/CD & Multi-Environment Infrastructure

[![AWS Fargate](https://img.shields.io/badge/AWS-ECS%20Fargate-orange?logo=amazon-aws)](https://aws.amazon.com/fargate/)
[![Terraform](https://img.shields.io/badge/Infrastructure%20as%20Code-Terraform-7B42BC?logo=terraform)](https://www.terraform.io/)
[![Jenkins](https://img.shields.io/badge/CI%2FCD-Jenkins-D33833?logo=jenkins)](https://www.jenkins.io/)
[![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/Backend-Python%20%2F%20Flask-3776AB?logo=python)](https://flask.palletsprojects.com/)

Production-ready DevOps repository featuring a multi-environment AWS ECS Fargate deployment architecture using Terraform modules, Application Load Balancers with Dual Target Groups (Blue/Green support), Amazon ECR, S3 remote state storage with DynamoDB state locking, and separate Jenkins CI/CD pipeline jobs for application and infrastructure management.

---

## 🏗 Repository Structure

```text
aws-ecs-fargate-cicd/
├── Jenkinsfile                      # App Deployment Pipeline (Docker Build, ECR Push, ECS Fargate Deploy)
├── app/                             # Application source code & container assets
│   ├── Dockerfile                   # Lightweight Python 3.11 container with Gunicorn
│   ├── app.py                       # Flask microservice with health endpoint
│   └── requirements.txt             # Flask & Gunicorn dependencies
└── terraform/                       # Infrastructure as Code
    ├── Jenkinsfile                  # Merged INFRA Pipeline (Dropdown for dev, qa, stage, production, bootstrap)
    ├── bootstrap/                   # S3 Remote State Bucket & DynamoDB Lock Table setup
    │   ├── main.tf                  # S3 bucket, versioning, AES256 encryption & DynamoDB table
    │   ├── outputs.tf
    │   └── variables.tf
    ├── modules/
    │   ├── vpc/                     # Reusable network module (VPC, Subnets, NAT, IGW)
    │   └── ecs-app/                 # ECS Fargate + ALB + Dual Target Groups (Blue/Green for Prod)
    └── environments/                # Environment-specific root configurations
        ├── dev/                     # dev/main.tf, dev/variables.tf, dev/backend.tf
        ├── qa/                      # qa/main.tf, qa/variables.tf, qa/backend.tf
        ├── stage/                   # stage/main.tf, stage/variables.tf, stage/backend.tf
        └── production/              # production/main.tf, production/variables.tf, production/backend.tf
```

---

## 🚀 Architecture Highlights

1. **Two Clean Merged Pipeline Flows**:
   - **Infrastructure Pipeline (`terraform/Jenkinsfile`)**: Merged INFRA setup flow with drop-down choice parameter for target environment (`bootstrap`, `dev`, `qa`, `stage`, `production`) and action (`plan`, `apply`, `destroy`). `destroy` action MANDATORILY requires manual interactive approval.
   - **Application Deployment Pipeline (`Jenkinsfile`)**: APP deploy flow for releasing container images (`ENVIRONMENT`: `dev`, `qa`, `stage`, `production`). Supports Blue/Green slotting (`blue`/`green`) exclusively for `production`.
   - **Automated Failure Diagnostics & Rollback (No `:latest` Dependency)**:
     - **Container Health Probes**: Configured with explicit `healthCheck` liveness probes (`curl -f http://localhost:5000/`) and ALB Target Group health checks.
     - **Startup & Probe Failure Diagnostics**: If container startup fails or health probes fail, the pipeline captures task stopped reasons and container exit codes (`aws ecs describe-tasks`).
     - **Automatic Revision Rollback**: Instantly restores the ECS service to the exact previous immutable Task Definition revision ARN and waits for health stabilization.
   - **Automated Security Scanning & Deployment Blockers (Snyk & Trivy)**:
     - **Snyk Dependency & Container Scan**: Scans `requirements.txt` dependencies and the built container image for vulnerabilities (`snyk test --severity-threshold=high`).
     - **Aqua Security Trivy Scan**: Scans the Docker image for OS and package vulnerabilities (`trivy image --exit-code 1 --severity HIGH,CRITICAL`).
     - **Deployment Gate**: If ANY `HIGH` or `CRITICAL` vulnerability is detected by Snyk or Trivy, the pipeline immediately halts, **blocking image push to ECR and blocking ECS deployment**.

2. **S3 Remote State Storage, DynamoDB Locking & Strict IAM Security**:
   - **Remote Backend**: All Terraform environments use AWS S3 bucket `devops-terraform-state-bucket-prod`.
   - **State Locking**: All `backend.tf` files configure DynamoDB table `devops-terraform-state-locks` to lock state files during concurrent executions.
   - **Strict IAM Access Controls**: 
     - **S3 Bucket Policy**: Enforces TLS/HTTPS-only transport (`aws:SecureTransport`) and blocks public access.
     - **Scoped IAM Roles & Policies**: Provisions dedicated IAM roles (`terraform-state-role-dev`, `qa`, `stage`, `production`) with least-privilege IAM policies restricting state file read/write operations strictly to each environment's S3 path prefix (`ecs-fargate/<env>/*`).

3. **Terraform Modular Infrastructure**:
   - **`vpc` module**: Provisioning dedicated VPCs, Public & Private subnets across multiple Availability Zones, Internet Gateways, Elastic IPs, NAT Gateways, and isolated Route Tables.
   - **`ecs-app` module**: Amazon ECR repository, Application Load Balancer (ALB) with **Dual Target Groups** (Blue on port `80`, Green on test port `8080` enabled **exclusively for Production** via `enable_blue_green = true`; single target group for non-prod), Security Groups, ECS Fargate Cluster, Task Definitions (`awsvpc` network mode, CloudWatch log streams), IAM Task Execution & Task Roles.

---

## 🛠 Deployment & Usage Instructions

### 1. INFRA Setup Pipeline (`terraform/Jenkinsfile`)

Configure a Jenkins Pipeline job pointing to `terraform/Jenkinsfile`.

Parameters:
- `ENVIRONMENT`: Dropdown choices `dev`, `qa`, `stage`, `production`, `bootstrap` (Select `bootstrap` to create S3 bucket & DynamoDB lock table).
- `ACTION`: Dropdown choices `plan`, `apply`, `destroy`.
- `AUTO_APPROVE`: Boolean flag (`false` prompts for approval before `apply`; **`destroy` MANDATORILY requires interactive approval prompt regardless**).

### 2. APP Deployment Pipeline (`Jenkinsfile`)

Configure a Jenkins Pipeline job pointing to root `Jenkinsfile`.

Parameters:
- `ENVIRONMENT`: `dev`, `qa`, `stage`, `production`
- `DEPLOY_SLOT`: `blue`, `green`, `none` (Blue/Green active exclusively for `production`)
- `FORCE_NEW_DEPLOYMENT`: `true`

---

## 📊 Environment Allocations & Subnet Specs

| Environment | VPC CIDR | Public Subnets | Private Subnets | Default Tasks | S3 State Key & Lock Table |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Dev** | `10.1.0.0/16` | `10.1.1.0/24`, `10.1.2.0/24` | `10.1.10.0/24`, `10.1.20.0/24` | `1` | `key: ecs-fargate/dev/terraform.tfstate`<br>`lock: devops-terraform-state-locks` |
| **QA** | `10.2.0.0/16` | `10.2.1.0/24`, `10.2.2.0/24` | `10.2.10.0/24`, `10.2.20.0/24` | `1` | `key: ecs-fargate/qa/terraform.tfstate`<br>`lock: devops-terraform-state-locks` |
| **Stage** | `10.3.0.0/16` | `10.3.1.0/24`, `10.3.2.0/24` | `10.3.10.0/24`, `10.3.20.0/24` | `2` | `key: ecs-fargate/stage/terraform.tfstate`<br>`lock: devops-terraform-state-locks` |
| **Production** | `10.0.0.0/16` | `10.0.1.0/24`, `10.0.2.0/24` | `10.0.10.0/24`, `10.0.20.0/24` | `2` | `key: ecs-fargate/production/terraform.tfstate`<br>`lock: devops-terraform-state-locks` |

 
