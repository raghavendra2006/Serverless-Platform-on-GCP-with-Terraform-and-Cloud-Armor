# Architecture — Enterprise Serverless Platform on GCP

## System Architecture Diagram

```mermaid
graph TB
    subgraph "Client Layer"
        Client["👤 Client / Browser"]
    end

    subgraph "Edge Security"
        CloudArmor["🛡️ Cloud Armor<br/>WAF + DDoS Protection"]
        GLB["⚖️ Global Load Balancer"]
    end

    subgraph "API Layer"
        APIGateway["🚪 API Gateway<br/>Routing + Rate Limiting"]
    end

    subgraph "Compute Layer"
        subgraph "Cloud Functions (2nd Gen)"
            FnUpload["📤 file-upload-function<br/>HTTP Trigger"]
            FnProcess["⚙️ file-process-function<br/>Eventarc Trigger"]
        end
        subgraph "Cloud Run"
            WebAPI["🌐 web-api Service<br/>FastAPI + SQLAlchemy"]
        end
    end

    subgraph "Data Layer"
        GCS["🪣 Cloud Storage<br/>File Uploads"]
        CloudSQL["🐘 Cloud SQL<br/>PostgreSQL 15"]
    end

    subgraph "Event Layer"
        PubSub["📬 Pub/Sub<br/>GCS Notifications"]
        Eventarc["⚡ Eventarc"]
    end

    subgraph "Security Layer"
        SecretMgr["🔐 Secret Manager<br/>DB Credentials"]
        IAM["🔑 IAM<br/>Least-Privilege SAs"]
    end

    subgraph "Observability"
        Logging["📋 Cloud Logging<br/>Structured JSON"]
        Monitoring["📊 Cloud Monitoring<br/>Alerts + Custom Metrics"]
        Trace["🔍 Cloud Trace<br/>Distributed Tracing"]
    end

    subgraph "Infrastructure"
        VPC["🌐 Custom VPC<br/>Private Networking"]
        VPCConn["🔌 VPC Connector<br/>Serverless Access"]
        Terraform["🏗️ Terraform<br/>Infrastructure as Code"]
    end

    subgraph "CI/CD"
        CloudBuild["🔄 Cloud Build<br/>Lint → Test → Plan → Apply"]
        ArtifactReg["📦 Artifact Registry<br/>Docker Images"]
    end

    %% Traffic flow
    Client --> CloudArmor
    CloudArmor --> GLB
    GLB --> APIGateway
    APIGateway -->|"/upload"| FnUpload
    APIGateway -->|"/api/*"| WebAPI

    %% Function flows
    FnUpload -->|"Save file"| GCS
    GCS -->|"Object finalize"| PubSub
    PubSub --> Eventarc
    Eventarc --> FnProcess

    %% Data access
    WebAPI -->|"Private IP"| CloudSQL
    WebAPI -->|"Fetch password"| SecretMgr

    %% VPC connectivity
    FnUpload -.-> VPCConn
    FnProcess -.-> VPCConn
    WebAPI -.-> VPCConn
    VPCConn -.-> VPC
    CloudSQL -.-> VPC

    %% Observability (dashed)
    FnUpload -.->|"Logs"| Logging
    FnProcess -.->|"Metrics"| Monitoring
    WebAPI -.->|"Traces"| Trace

    %% CI/CD
    CloudBuild -->|"Deploy"| Terraform
    CloudBuild -->|"Push image"| ArtifactReg

    %% Styling
    classDef security fill:#ff6b6b,stroke:#c92a2a,color:#fff
    classDef compute fill:#4dabf7,stroke:#1971c2,color:#fff
    classDef data fill:#51cf66,stroke:#2f9e44,color:#fff
    classDef observability fill:#ffd43b,stroke:#f08c00,color:#333
    classDef infra fill:#845ef7,stroke:#5f3dc4,color:#fff

    class CloudArmor,SecretMgr,IAM security
    class FnUpload,FnProcess,WebAPI compute
    class GCS,CloudSQL data
    class Logging,Monitoring,Trace observability
    class VPC,VPCConn,Terraform infra
```

## Request Flow

### File Upload Flow
1. Client sends `POST /upload` with `multipart/form-data`
2. Cloud Armor inspects the request (WAF rules, rate limiting)
3. Global Load Balancer forwards to API Gateway
4. API Gateway routes to `file-upload-function`
5. Function saves the file to Cloud Storage bucket
6. GCS emits an `OBJECT_FINALIZE` event via Pub/Sub
7. Eventarc triggers `file-process-function`
8. Process function logs metadata and increments custom metric

### API Request Flow
1. Client sends `GET /api/items`
2. Cloud Armor → Global LB → API Gateway
3. API Gateway routes to Cloud Run `web-api` service
4. Service fetches DB password from Secret Manager (cached)
5. Service queries Cloud SQL via private IP (VPC Connector)
6. Response returned through the same path

## Security Architecture

| Layer | Component | Purpose |
|-------|-----------|---------|
| Edge | Cloud Armor | WAF (XSS, SQLi), IP blocking, rate limiting |
| Network | Custom VPC | Private networking, no public IPs on data tier |
| Identity | IAM Service Accounts | Least-privilege access per service |
| Secrets | Secret Manager | DB credentials secured, not in env vars |
| Data | Cloud SQL | Private IP only, encrypted at rest |

## Observability Stack

| Pillar | Tool | Implementation |
|--------|------|----------------|
| Logs | Cloud Logging | Structured JSON with `severity` + `service_context` |
| Metrics | Cloud Monitoring | Custom `files_processed_count` counter + alerts |
| Traces | Cloud Trace | Distributed tracing across API Gateway → Cloud Run |
