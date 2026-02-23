# Runbook — Enterprise Serverless Platform

## Table of Contents
- [Incident: 5xx Error Rate Spike](#incident-5xx-error-rate-spike)
- [Incident: Cloud Function Execution Failures](#incident-cloud-function-execution-failures)
- [Incident: Cloud SQL High CPU](#incident-cloud-sql-high-cpu)
- [Incident: Cloud Armor Blocking Legitimate Traffic](#incident-cloud-armor-blocking-legitimate-traffic)
- [Operational: Rotating Database Credentials](#operational-rotating-database-credentials)

---

## Incident: 5xx Error Rate Spike

**Alert**: `Cloud Run 5xx Error Rate (dev)` — triggers when 5xx responses exceed 5/min.

### Severity Assessment
| 5xx Rate | Impact | Severity |
|----------|--------|----------|
| < 5/min | Low — possible transient issues | P3 |
| 5–50/min | Medium — users affected | P2 |
| > 50/min | High — service degradation | P1 |

### Investigation Steps

**1. Check Cloud Logging for errors**
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --project=YOUR_PROJECT_ID \
  --format="table(timestamp, jsonPayload.message)" \
  --limit=50 \
  --freshness=1h
```

**2. Check Cloud Run service status**
```bash
gcloud run services describe web-api-dev \
  --region=us-central1 \
  --format="yaml(status)"
```

**3. Check Cloud Monitoring dashboard**
- Navigate to: **Monitoring → Dashboards → Cloud Run**
- Look for correlations: CPU spikes, memory pressure, request latency

**4. Check Cloud SQL connectivity**
```bash
gcloud sql instances describe <INSTANCE_NAME> \
  --format="yaml(state, settings.ipConfiguration)"
```

### Common Causes & Remediation

| Cause | Symptoms | Fix |
|-------|----------|-----|
| Database connection exhaustion | `too many connections` in logs | Increase `pool_size` in app config or scale Cloud SQL tier |
| Secret Manager access failure | `PermissionDenied` errors | Verify IAM bindings: `roles/secretmanager.secretAccessor` |
| Container startup failure | `Container failed to start` | Check Dockerfile, memory limits; review startup probe config |
| Upstream dependency timeout | Timeout errors in traces | Check VPC Connector health; verify private networking |

**5. Rollback if needed**
```bash
# List revisions
gcloud run revisions list --service=web-api-dev --region=us-central1

# Route traffic to previous healthy revision
gcloud run services update-traffic web-api-dev \
  --region=us-central1 \
  --to-revisions=<PREVIOUS_REVISION>=100
```

---

## Incident: Cloud Function Execution Failures

**Alert**: `Cloud Function Execution Errors` — triggers when error count > 10 in 5 minutes.

### Investigation Steps

**1. Check function logs**
```bash
gcloud logging read \
  'resource.type="cloud_function" AND severity>=ERROR' \
  --project=YOUR_PROJECT_ID \
  --limit=20 \
  --freshness=1h
```

**2. Check function status**
```bash
gcloud functions describe file-upload-dev --gen2 --region=us-central1
gcloud functions describe file-process-dev --gen2 --region=us-central1
```

### Common Causes & Remediation

| Cause | Fix |
|-------|-----|
| GCS bucket permissions | Verify service account has `storage.objectAdmin` |
| Pub/Sub delivery failure | Check dead-letter queue; verify subscription health |
| Memory/timeout exceeded | Increase `available_memory` or `timeout_seconds` in Terraform |

---

## Incident: Cloud SQL High CPU

**Alert**: `Cloud SQL High CPU Utilization` — triggers when CPU > 80% for 5 minutes.

### Investigation Steps

**1. Check active queries**
```sql
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;
```

**2. Check connection count**
```sql
SELECT count(*) FROM pg_stat_activity;
```

### Remediation
- Kill long-running queries: `SELECT pg_cancel_backend(<pid>);`
- Scale instance tier: update `db_tier` in `terraform.tfvars` and apply
- Add missing indexes based on **pg_stat_user_tables** `seq_scan` counts

---

## Incident: Cloud Armor Blocking Legitimate Traffic

### Investigation Steps

**1. Check Cloud Armor logs**
```bash
gcloud logging read \
  'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.outcome="DENY"' \
  --limit=20
```

**2. List current security policy rules**
```bash
gcloud compute security-policies describe platform-security-policy-dev
```

### Remediation
- Add the IP to an allowlist rule with higher priority
- Switch the rule to **preview mode** while investigating:
  - Update Terraform: `preview = true` on the rule

---

## Operational: Rotating Database Credentials

**Steps:**
1. Generate a new password in Secret Manager
2. Create a new version of the secret
3. Restart Cloud Run to pick up the new secret version

```bash
# Create a new secret version
echo -n "NEW_PASSWORD_HERE" | \
  gcloud secrets versions add cloudsql-db-password-dev --data-file=-

# Update the Cloud SQL user password
gcloud sql users set-password platform_user \
  --instance=<INSTANCE_NAME> \
  --password="NEW_PASSWORD_HERE"

# Force Cloud Run to restart and fetch the new secret
gcloud run services update web-api-dev \
  --region=us-central1 \
  --update-env-vars="FORCE_RESTART=$(date +%s)"
```

---

## Escalation Path

| Severity | Response Time | Notification |
|----------|---------------|-------------|
| P1 — Critical | 15 min | Page on-call + Slack #incidents |
| P2 — Major | 30 min | Slack #incidents |
| P3 — Minor | Next business day | Email alert |
