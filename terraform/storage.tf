# ============================================================================
# Cloud Storage — File Upload Bucket
# ============================================================================

resource "google_storage_bucket" "uploads" {
  name          = "platform-uploads-${var.environment}-${random_id.suffix.hex}"
  location      = var.gcp_region
  force_destroy = var.environment != "prod"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "POST", "PUT"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }

  labels = local.common_labels
}

# Pub/Sub notification for new objects (used by file-process function)
resource "google_storage_notification" "uploads_notification" {
  bucket         = google_storage_bucket.uploads.name
  payload_format = "JSON_API_V1"
  event_types    = ["OBJECT_FINALIZE"]
  topic          = google_pubsub_topic.gcs_notifications.id

  depends_on = [google_pubsub_topic_iam_binding.gcs_publisher]
}

# Pub/Sub topic for GCS notifications
resource "google_pubsub_topic" "gcs_notifications" {
  name   = "gcs-upload-notifications-${var.environment}"
  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}

# Allow GCS to publish to the Pub/Sub topic
data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_binding" "gcs_publisher" {
  topic   = google_pubsub_topic.gcs_notifications.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}
