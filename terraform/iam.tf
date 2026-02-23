# ============================================================================
# IAM — Service Accounts & Least-Privilege Bindings
# ============================================================================

# ----------------------------------------------------------------------------
# Service Accounts
# ----------------------------------------------------------------------------

# Cloud Function — file upload
resource "google_service_account" "function_upload" {
  account_id   = "fn-upload-${var.environment}"
  display_name = "File Upload Function SA (${var.environment})"
  description  = "Service account for the file-upload Cloud Function."
}

# Cloud Function — file process
resource "google_service_account" "function_process" {
  account_id   = "fn-process-${var.environment}"
  display_name = "File Process Function SA (${var.environment})"
  description  = "Service account for the file-process Cloud Function."
}

# Cloud Run — web API
resource "google_service_account" "cloud_run_api" {
  account_id   = "cloudrun-api-${var.environment}"
  display_name = "Cloud Run Web API SA (${var.environment})"
  description  = "Service account for the Cloud Run web-api service."
}

# ----------------------------------------------------------------------------
# IAM Bindings — Least Privilege (NO primitive roles)
# ----------------------------------------------------------------------------

# File Upload Function permissions
resource "google_project_iam_member" "fn_upload_storage" {
  project = var.gcp_project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.function_upload.email}"
}

resource "google_project_iam_member" "fn_upload_logging" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.function_upload.email}"
}

resource "google_project_iam_member" "fn_upload_tracing" {
  project = var.gcp_project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.function_upload.email}"
}

# File Process Function permissions
resource "google_project_iam_member" "fn_process_storage" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.function_process.email}"
}

resource "google_project_iam_member" "fn_process_monitoring" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.function_process.email}"
}

resource "google_project_iam_member" "fn_process_logging" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.function_process.email}"
}

resource "google_project_iam_member" "fn_process_tracing" {
  project = var.gcp_project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.function_process.email}"
}

resource "google_project_iam_member" "fn_process_eventarc" {
  project = var.gcp_project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.function_process.email}"
}

# Cloud Run Web API permissions
resource "google_project_iam_member" "cloudrun_cloudsql" {
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_api.email}"
}

resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_api.email}"
}

resource "google_project_iam_member" "cloudrun_logging" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_api.email}"
}

resource "google_project_iam_member" "cloudrun_tracing" {
  project = var.gcp_project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.cloud_run_api.email}"
}

resource "google_project_iam_member" "cloudrun_monitoring" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_api.email}"
}
