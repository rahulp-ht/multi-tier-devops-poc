# Multi-Tier DevOps POC

A multi-tier application deployment POC demonstrating local
containerization, Jenkins CI/CD, Terraform-based AWS infrastructure, and
deployment to Amazon ECS using the EC2 launch type.

- **Repository:** https://github.com/rahulp-ht/multi-tier-devops-poc
- **Application:** https://poc.therahulpatil.in
- **AWS Region:** `ap-south-1` (Mumbai)
- **Verified:** 17 November 2026

## 1. Project Overview

The application contains three tiers:

| Tier     | Technology                    | Responsibility                 |
|----------|-------------------------------|--------------------------------|
| Frontend | React + Vite, served by Nginx | Books and Authors UI           |
| Backend  | Node.js + Express             | REST API and application logic |
| Database | MySQL on Amazon RDS           | Persistent application data    |

The POC uses Docker for containerization, Jenkins for CI/CD, SonarQube
for static analysis, Trivy for container image scanning, Amazon ECR for
image storage, Amazon ECS on EC2 for orchestration, and Terraform for
infrastructure provisioning.

## 2. Architecture

``` mermaid
flowchart LR
    GH[GitHub repository] --> CI[Jenkins CI]
    CI --> SQ[SonarQube SAST and Quality Gate]
    SQ --> TR[Trivy image scans]
    TR --> CD[Jenkins CD]
    CD --> ECR[Amazon ECR<br/>Backend and Frontend digests]
    ECR --> ECS[Amazon ECS cluster<br/>EC2 launch type]
    U[Users] --> ALB[Application Load Balancer<br/>HTTP 80 / HTTPS 443]
    ALB -->|/api/*| BE[Backend service<br/>2 tasks]
    ALB -->|Default route| FE[Frontend service<br/>2 tasks]
    BE --> RDS[(Amazon RDS MySQL)]
    BE --> SM[AWS Secrets Manager]
    CW[Amazon CloudWatch] -. monitors .-> ECS
    CW -. monitors .-> ALB
    CW -. monitors .-> RDS
    TF[Terraform] -. provisions .-> ECS
    TF -. provisions .-> ALB
    TF -. provisions .-> RDS
    TF -. provisions .-> ECR
```

### Main AWS components

| Component              | Configuration / role                                               |
|------------------------|--------------------------------------------------------------------|
| VPC                    | `multi-tier-poc-vpc`, CIDR `10.0.0.0/16`                           |
| Subnets                | Four public/private subnets across `ap-south-1a` and `ap-south-1b` |
| ALB                    | `multi-tier-poc-alb`; HTTP :80 and HTTPS :443                      |
| ECS cluster            | `multi-tier-poc-cluster`                                           |
| ECS services           | `multi-tier-poc-backend` and `multi-tier-poc-frontend`             |
| EC2 Auto Scaling Group | `multi-tier-poc-ecs-asg`; min 2, desired 2, max 4                  |
| EC2 instance type      | `c7i-flex.large`                                                   |
| ECR repositories       | `multi-tier-poc/backend`, `multi-tier-poc/frontend`                |
| RDS                    | `multi-tier-poc-db`; MySQL Community, `db.t3.micro`, 20 GiB        |
| Database name          | `react_node_app`                                                   |
| Secrets Manager        | `multi-tier-poc/app-db`                                            |
| CloudWatch dashboard   | `multi-tier-poc-monitoring`                                        |

## 3. Repository Layout

The main project areas are:

``` text
multi-tier-devops-poc/
├── backend/                     # Node.js / Express API
├── frontend/                    # React / Vite application
├── terraform/                   # AWS infrastructure as code
├── scripts/
│   └── cleanup-ecs-capacity.sh  # Guarded ECS/ASG capacity cleanup
├── compose.yaml                 # Local multi-container application
├── Jenkinsfile                  # CI pipeline definition
└── Jenkinsfile.cd               # CD pipeline definition
```

Check the repository for the current file names and any additional
environment-specific files.

## 4. Local Application Validation

From the repository root:

``` bash
docker compose up -d --build
docker compose ps
docker compose logs -f
```

To stop the local Compose application:

``` bash
docker compose down
```

The local Swarm validation also showed the `multi-tier-poc` stack with
backend, frontend and MySQL services at the expected replica count in
the captured terminal evidence.

Keep environment files such as `.env` out of Git. Do not commit database
passwords, tokens, AWS access keys, or other secrets.

## 5. Jenkins CI Pipeline

Jenkins job: `multi-tier-poc-ci`

The CI flow shown in Jenkins contains:

1.  SCM Checkout
2.  Validate Source
3.  SonarQube SAST
4.  Build Docker Images
5.  Trivy Security Reports
6.  Security Quality Gates
7.  Declarative Post Actions

### CI verification result

- Successful CI build: **\#25**
- SonarQube Quality Gate: **Passed**
- Trivy: backend and frontend image scans executed
- Reports archived by Jenkins: `report-task.txt`, `quality-gate.txt`,
  `backend.json`, `backend.txt`, `frontend.json`, `frontend.txt`

The captured SonarQube summary showed 0 new issues, 0 accepted issues
and 0 security hotspots. Coverage and duplication were not computed in
that summary.

## 6. Jenkins CD Pipeline

Jenkins job: `multi-tier-poc-cd`

The CD pipeline is triggered from the successful upstream CI job and
verifies that the supplied build number, commit SHA and image IDs
correspond to the CI-tested build. CD deliberately does not rebuild the
application images.

The captured CD stages are:

1.  Checkout Deployment Scripts
2.  Verify Successful CI Build
3.  Prepare AWS CLI
4.  Push Tested Images to ECR
5.  Prepare Rolling Deployment Capacity
6.  Deploy Approved Digests to ECS
7.  Declarative Post Actions

### Successful deployment evidence

- Successful CD build: **\#16**
- Upstream CI build: **\#25**
- ECS cluster: `multi-tier-poc-cluster`
- Services deployed: backend and frontend
- Final status: **DEPLOYMENT VERIFIED**

The CD flow pushes the tested images to ECR, captures their SHA-256
digests, and uses those approved digests for ECS task definitions. This
prevents a mutable tag from silently changing the deployed image.

## 7. Verified Image References

Image tag used by the successful deployment:

``` text
59bf35a2d4e6a6cd61061110142964d664b28c95-25
```

| Image    | ECR repository            | Verified digest                                                           |
|----------|---------------------------|---------------------------------------------------------------------------|
| Backend  | `multi-tier-poc/backend`  | `sha256:8c0b0103fc17ba23ddd8b310651d98bd05e6e24fe294014614dff20fa76f3c80` |
| Frontend | `multi-tier-poc/frontend` | `sha256:1ee6052393d51ded41207134c7484d8817be05f45479f310a6cf9cb16cc11623` |

The ECR registry URI is account-specific. Configure the account ID and
registry in Jenkins environment settings rather than copying credentials
into source code.

## 8. ECS Deployment State

The captured final state showed:

| Service                   | Desired | Running | Pending | Task definition | Rollout   |
|---------------------------|--------:|--------:|--------:|----------------:|-----------|
| `multi-tier-poc-backend`  |       2 |       2 |       0 |     Revision 17 | COMPLETED |
| `multi-tier-poc-frontend` |       2 |       2 |       0 |     Revision 16 | COMPLETED |

The ECS cluster showed four running tasks and two registered container
instances.

### Check service health

``` bash
aws ecs describe-services \
  --cluster multi-tier-poc-cluster \
  --services multi-tier-poc-backend multi-tier-poc-frontend \
  --region ap-south-1 \
  --query 'services[*].{Service:serviceName,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Rollout:deployments[0].rolloutState}' \
  --output table
```

### Check Auto Scaling capacity

The captured Auto Scaling Group configuration was:

- Minimum: 2
- Desired: 2
- Maximum: 4
- Current healthy instances: 2
- Instance type: `c7i-flex.large`

## 9. Traffic Routing

The Application Load Balancer has:

- HTTP listener on port `80`
- HTTPS listener on port `443`
- `/api/*` path rule forwarding to the backend target group
- Default rule forwarding to the frontend target group

The captured ALB overview showed two healthy targets in each target
group.

## 10. Secrets and Monitoring

### Secrets Manager

Database credentials are stored in the secret:

``` text
multi-tier-poc/app-db
```

The secret value must not be committed to Git, printed in build logs, or
copied into this README.

### CloudWatch

Dashboard:

``` text
multi-tier-poc-monitoring
```

Captured widgets include:

- ECS CPU utilization
- ECS memory utilization
- ALB target response time
- RDS CPU utilization and database connections

## 11. Terraform

Terraform is used to provision and track the AWS infrastructure. The
captured Terraform state output included resources for networking,
security groups, load balancing, ECR, ECS, EC2 capacity, IAM, RDS,
Secrets Manager and CloudWatch logging.

Typical validation workflow from the Terraform directory:

``` bash
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Apply infrastructure only after reviewing the plan and confirming the
expected AWS account, region and cost.

## 12. Jenkins Credentials and Security Notes

Configure credentials in Jenkins Credentials; do not put secret values
in the Jenkinsfile or Git repository.

Credentials referenced in the pipeline evidence include:

- `github-poc-token` — GitHub repository access
- `aws-ecr-credentials` — AWS credentials used by the deployment
  pipeline

The AWS identity needs only the permissions required by the pipeline.
Scope `iam:PassRole` to the required ECS task and execution roles. Some
AWS `Describe*` actions require `Resource: "*"`; keep those read-only
permissions separate from resource-mutating permissions.

## 13. Cleanup and Cost Control

The AWS environment includes billable resources, including EC2 capacity,
RDS and the Application Load Balancer. Check current AWS billing before
leaving the environment running.

Before teardown:

1.  Preserve the report, screenshots, Terraform state and any required
    database backup.
2.  Review the Terraform state and identify all resources managed by
    this configuration.
3.  Run and review a destroy plan.
4.  Destroy resources only after confirming that no data or
    infrastructure must be retained.
5.  Verify remaining resources in the AWS console and review Cost
    Explorer.

Example destroy-plan command:

``` bash
cd terraform
terraform plan -destroy
```

Do not run `terraform destroy` until the plan has been reviewed and
approved.

## 14. Final Outcome

The POC successfully demonstrated:

- Local containerization of the frontend, backend and MySQL tiers
- Jenkins CI with source validation, SonarQube, Docker builds and Trivy
  scans
- CI quality gate enforcement and report archiving
- CD verification of upstream CI output and tested image identity
- ECR image publication using SHA-256 digests
- Rolling deployment to ECS on EC2 capacity
- ALB routing to separate frontend and backend services
- RDS MySQL integration and Secrets Manager-based credential storage
- Terraform-based AWS infrastructure management
- CloudWatch operational monitoring

**Final verified status:** Jenkins CI build \#25 — Success; Jenkins CD
build \#16 — Success; ECS backend and frontend services — 2/2 tasks
running each; deployment status — verified.
