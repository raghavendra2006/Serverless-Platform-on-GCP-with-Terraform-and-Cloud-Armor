# ============================================================================
# Cloud Functions (2nd Gen) — File Upload & File Process
# ============================================================================

# ----------------------------------------------------------------------------
# Source code archive bucket
# ----------------------------------------------------------------------------

resource "google_storage_bucket" "function_source" {
  name          = "fn-source-${var.environment}-${random_id.suffix.hex}"
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true
  labels                      = local.common_labels
}

# ----------------------------------------------------------------------------
# File Upload Function — source archive
# ----------------------------------------------------------------------------

data "archive_file" "file_upload" {
  type        = "zip"
  source_dir  = "${path.module}/../services/file-upload-function"
  output_path = "${path.module}/.build/file-upload-function.zip"
}

resource "google_storage_bucket_object" "file_upload_source" {
  name   = "file-upload-function-${data.archive_file.file_upload.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.file_upload.output_path
}

# File Upload Cloud Function (2nd Gen, HTTP trigger)
resource "google_cloudfunctions2_function" "file_upload" {
  name     = "file-upload-${var.environment}"
  location = var.gcp_region

  build_config {
    runtime     = "python311"
    entry_point = "upload_file"

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.file_upload_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 120
    service_account_email = google_service_account.function_upload.email

    environment_variables = {
      GCS_BUCKET_NAME = google_storage_bucket.uploads.name
      ENVIRONMENT     = var.environment
    }

    vpc_connector                 = google_vpc_access_connector.main.id
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
  }

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}

# Allow unauthenticated access to the upload function (via API Gateway)
resource "google_cloud_run_service_iam_member" "function_upload_invoker" {
  project  = var.gcp_project_id
  location = var.gcp_region
  service  = google_cloudfunctions2_function.file_upload.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ----------------------------------------------------------------------------
# File Process Function — source archive
# ----------------------------------------------------------------------------

data "archive_file" "file_process" {
  type        = "zip"
  source_dir  = "${path.module}/../services/file-process-function"
  output_path = "${path.module}/.build/file-process-function.zip"
}

resource "google_storage_bucket_object" "file_process_source" {
  name   = "file-process-function-${data.archive_file.file_process.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.file_process.output_path
}

# File Process Cloud Function (2nd Gen, Eventarc trigger)
resource "google_cloudfunctions2_function" "file_process" {
  name     = "file-process-${var.environment}"
  location = var.gcp_region

  build_config {
    runtime     = "python311"
    entry_point = "process_file"

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.file_process_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 300
    service_account_email = google_service_account.function_process.email

    environment_variables = {
      GCP_PROJECT_ID = var.gcp_project_id
      ENVIRONMENT    = var.environment
    }

    vpc_connector                 = google_vpc_access_connector.main.id
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
  }

  event_trigger {
    trigger_region        = var.gcp_region
    event_type            = "google.cloud.storage.object.v1.finalized"
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.function_process.email

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.uploads.name
    }
  }

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}
