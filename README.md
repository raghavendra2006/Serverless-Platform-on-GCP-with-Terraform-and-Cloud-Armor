# 🚀 Enterprise Serverless Platform on GCP

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.3-623CE4?logo=terraform)](https://www.terraform.io/)
[![GCP](https://img.shields.io/badge/Google%20Cloud-Platform-4285F4?logo=google-cloud)](https://cloud.google.com/)
[![Cloud Armor](https://img.shields.io/badge/Cloud%20Armor-WAF%20%2B%20DDoS-FF6B6B)](https://cloud.google.com/armor)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A **production-grade, multi-service serverless application** on Google Cloud Platform, fully managed through Infrastructure as Code (Terraform), hardened with Cloud Armor WAF, and instrumented with a complete observability stack.

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Key Features](#key-features)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start — Local Development](#quick-start--local-development)
- [GCP Deployment](#gcp-deployment)
- [API Reference](#api-reference)
- [Security](#security)
- [Observability](#observability)
- [CI/CD Pipeline](#cicd-pipeline)
- [Infrastructure Details](#infrastructure-details)
- [Disaster Recovery](#disaster-recovery)
- [Cost Optimization](#cost-optimization)
- [Contributing](#contributing)

---

## Architecture Overview

```
Client → Cloud Armor (WAF) → Global LB → API Gateway
                                             ├── /upload  → Cloud Function → GCS → Pub/Sub → Cloud Function (process)
                                             └── /api/*   → Cloud Run (FastAPI) → Cloud SQL (PostgreSQL)
```

All components communicate over a **custom VPC** with private networking. See the full [Architecture Diagram](docs/architecture.md) with detailed Mermaid diagrams and data flow descriptions.

---

## Key Features

### 🏗️ Infrastructure as Code
- **13 Terraform files** managing the entire GCP infrastructure
- Modular design — VPC, Cloud SQL, Cloud Functions, Cloud Run, API Gateway, Cloud Armor, IAM, Secret Manager, Monitoring
- Environment-aware (`dev`, `staging`, `prod`) with variable-driven configuration

### 🔒 Defense-in-Depth Security
- **Cloud Armor WAF** — XSS, SQLi protection, IP blocking, rate limiting (100 req/min per IP)
- **Secret Manager** — DB credentials fetched at runtime (never in env vars)
- **Least-Privilege IAM** — Dedicated service accounts per service, no primitive roles
- **Private Networking** — Cloud SQL has no public IP; all serverless services use VPC Connector

### 📊 Full Observability Stack
- **Structured JSON Logging** — `severity` + `service_context` fields across all services
- **Custom Metrics** — `custom.googleapis.com/files_processed_count` counter
- **Distributed Tracing** — End-to-end trace propagation through API Gateway → Cloud Run
- **Alerting** — 5xx error rate, function failures, Cloud SQL CPU utilization

### ⚡ Serverless Compute
- **Cloud Functions (2nd Gen)** — File upload (HTTP) + File processing (Eventarc)
- **Cloud Run** — Containerized FastAPI web API with connection pooling
- **Auto-scaling** — 0 to N instances based on demand

---

## Project Structure

```
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Provider config, API enablement
│   ├── variables.tf              # All variable definitions
│   ├── outputs.tf                # Output values
│   ├── vpc.tf                    # Custom VPC, subnets, firewall rules
│   ├── cloudsql.tf               # PostgreSQL with private networking
│   ├── storage.tf                # GCS bucket + Pub/Sub notifications
│   ├── iam.tf                    # Service accounts + IAM bindings
│   ├── secret_manager.tf         # Database password in Secret Manager
│   ├── cloud_functions.tf        # 2nd Gen Cloud Functions
│   ├── cloud_run.tf              # Cloud Run v2 service + Artifact Registry
│   ├── api_gateway.tf            # API Gateway + OpenAPI config
│   ├── cloud_armor.tf            # WAF policy + Global Load Balancer
│   ├── monitoring.tf             # Alert policies + notification channels
│   ├── terraform.tfvars.example  # Example variable values
│   └── templates/
│       └── openapi.yaml.tpl      # API Gateway OpenAPI spec template
├── services/
│   ├── file-upload-function/     # HTTP Cloud Function (Python)
│   │   ├── main.py
│   │   └── requirements.txt
│   ├── file-process-function/    # Eventarc Cloud Function (Python)
│   │   ├── main.py
│   │   └── requirements.txt
│   └── web-api/                  # Cloud Run service (FastAPI)
│       ├── main.py
│       ├── requirements.txt
│       ├── Dockerfile
│       ├── .dockerignore
│       └── tests/
│           └── test_main.py
├── scripts/
│   └── init-db.sql               # Database initialization script
├── docs/
│   ├── architecture.md           # Architecture diagram (Mermaid)
│   └── runbook.md                # Operational runbook
├── cloudbuild.yaml               # CI/CD pipeline (Cloud Build)
├── docker-compose.yml            # Local development setup
├── .env.example                  # Environment variable template
├── .gitignore
└── README.md                     # This file
```

---

## Prerequisites

- **GCP Account** with billing enabled
- **gcloud CLI** installed and authenticated
- **Terraform** >= 1.3
- **Docker** & **Docker Compose** (for local development)
- **Python** 3.11+ (for running services locally)

---

## Quick Start — Local Development

### 1. Clone the repository
```bash
git clone https://github.com/your-username/Serverless-Platform-on-GCP-with-Terraform-and-Cloud-Armor.git
cd Serverless-Platform-on-GCP-with-Terraform-and-Cloud-Armor
```

### 2. Configure environment
```bash
cp .env.example .env
# Edit .env with your local settings (default values work for Docker)
```

### 3. Start services
```bash
docker-compose up -d --build
```

### 4. Verify
```bash
# Check service health
docker-compose ps

# Test the API
curl http://localhost:8080/health
curl http://localhost:8080/items
```

---

## GCP Deployment

### 1. Authenticate
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Configure Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID and preferences
```

### 3. Deploy infrastructure
```bash
terraform init
terraform plan
terraform apply
```

### 4. Build and push the container
```bash
# After Terraform creates the Artifact Registry
IMAGE="us-central1-docker.pkg.dev/YOUR_PROJECT/platform-services-dev/web-api:latest"
docker build -t $IMAGE ./services/web-api
docker push $IMAGE

# Update Terraform with the new image
terraform apply -var="cloud_run_image=$IMAGE"
```

### 5. Test deployment
```bash
# Get the API Gateway URL
GATEWAY_URL=$(terraform output -raw api_gateway_url)

# Upload a file
curl -X POST -F "file=@test.txt" $GATEWAY_URL/upload

# Query items
curl $GATEWAY_URL/api/items
```

---

## API Reference

| Method | Endpoint | Service | Description |
|--------|----------|---------|-------------|
| `POST` | `/upload` | Cloud Function | Upload a file to GCS |
| `GET` | `/api/items` | Cloud Run | List all items from DB |
| `POST` | `/api/items` | Cloud Run | Create a new item |
| `GET` | `/api/health` | Cloud Run | Health check |

### Upload File
```bash
curl -X POST -F "file=@document.pdf" https://GATEWAY_URL/upload
# Response: 201 {"filename": "document.pdf", "bucket": "platform-uploads-dev-a1b2c3d4"}
```

### List Items
```bash
curl https://GATEWAY_URL/api/items
# Response: 200 [{"id": 1, "name": "...", "description": "...", "created_at": "..."}]
```

---

## Security

### Cloud Armor WAF Rules

| Priority | Rule | Action |
|----------|------|--------|
| 1000 | Block IP range `192.0.2.0/24` | `deny(403)` |
| 2000 | XSS attack patterns | `deny(403)` |
| 2100 | SQL Injection patterns | `deny(403)` |
| 3000 | Rate limiting (100 req/min/IP) | `throttle` / `deny(429)` |
| Default | All other traffic | `allow` |

### IAM — Least Privilege

| Service Account | Roles |
|----------------|-------|
| `fn-upload-*` | `storage.objectAdmin`, `logging.logWriter`, `cloudtrace.agent` |
| `fn-process-*` | `storage.objectViewer`, `monitoring.metricWriter`, `logging.logWriter`, `cloudtrace.agent`, `eventarc.eventReceiver` |
| `cloudrun-api-*` | `cloudsql.client`, `secretmanager.secretAccessor`, `logging.logWriter`, `cloudtrace.agent`, `monitoring.metricWriter` |

> ⚠️ **No primitive roles** (`owner`, `editor`, `viewer`) are used anywhere.

### Secrets Management
The Cloud SQL password is stored in **Secret Manager** and fetched by the Cloud Run service at startup. It is **never** passed as a plain-text environment variable.

---

## Observability

### Structured Logging
All services emit JSON logs with these fields:
```json
{
  "severity": "INFO",
  "message": "File uploaded successfully",
  "service_context": {"service": "file-upload-function"},
  "filename": "document.pdf"
}
```

### Custom Metrics
- **Metric**: `custom.googleapis.com/files_processed_count`
- **Type**: Counter (incremented per file processed)
- **Source**: `file-process-function`

### Alerts
| Alert | Condition | Notification |
|-------|-----------|-------------|
| 5xx Error Rate | > 5 errors/min on Cloud Run | Email |
| Function Errors | > 10 errors/5min on Cloud Functions | Email |
| Cloud SQL CPU | > 80% for 5 minutes | Email |

---

## CI/CD Pipeline

The `cloudbuild.yaml` defines a 6-step pipeline:

```
┌─────────┐    ┌──────┐    ┌─────────────┐    ┌────────────┐    ┌────────┐    ┌────────┐
│  Lint   │ →  │ Test │ →  │ Build Image │ →  │ Push Image │ →  │ TF Plan│ →  │TF Apply│
└─────────┘    └──────┘    └─────────────┘    └────────────┘    └────────┘    └────────┘
```

Trigger manually:
```bash
gcloud builds submit --config cloudbuild.yaml .
```

---

## Infrastructure Details

### Networking
- **Custom VPC** — `auto_create_subnetworks = false`
- **Private subnet** — `10.10.0.0/24` with flow logs
- **VPC Connector** — Serverless access to private resources
- **Private Services Access** — Cloud SQL private IP via VPC peering
- **Firewall** — Allow internal + health checks; deny all other ingress

### Cloud SQL
- **Engine**: PostgreSQL 15
- **Tier**: `db-g1-small` (configurable)
- **Private IP only** — `ipv4_enabled = false`
- **Automated backups** — Daily at 03:00, 7-day retention
- **Connection pooling** — SQLAlchemy pool with `pool_pre_ping`

### Resource Labels
All resources are tagged:
```hcl
labels = {
  project     = "serverless-platform"
  environment = "dev"
  managed_by  = "terraform"
}
```

---

## Disaster Recovery

### Manual DR Steps
1. **Database**: Cloud SQL has daily backups with 7-day retention. Restore via:
   ```bash
   gcloud sql backups restore BACKUP_ID --restore-instance=NEW_INSTANCE
   ```
2. **Multi-region**: Update `gcp_region` in `terraform.tfvars` and run `terraform apply` to deploy to another region.
3. **Rollback**: Cloud Run revisions allow instant traffic shifting:
   ```bash
   gcloud run services update-traffic web-api-dev --to-revisions=PREVIOUS_REV=100
   ```

For detailed incident response procedures, see the [Runbook](docs/runbook.md).

---

## Cost Optimization

- **Labels** on all resources for granular billing analysis
- **Lifecycle policies** on GCS — transition to Nearline after 90 days, delete after 365
- **Scale-to-zero** — Cloud Run and Cloud Functions scale to 0 when idle
- **`db-g1-small`** tier for dev (upgrade for prod via `db_tier` variable)
- **Budget alerts** recommended via GCP Billing console

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and test locally with `docker-compose up`
4. Submit a pull request
