# ============================================================================
# Cloud Run — Web API Service
# ============================================================================

# Artifact Registry repository for container images
resource "google_artifact_registry_repository" "main" {
  location      = var.gcp_region
  repository_id = "platform-services-${var.environment}"
  format        = "DOCKER"
  description   = "Container images for the serverless platform (${var.environment})"

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}

# Cloud Run v2 service
resource "google_cloud_run_v2_service" "web_api" {
  name     = "web-api-${var.environment}"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    service_account = google_service_account.cloud_run_api.email

    vpc_access {
      connector = google_vpc_access_connector.main.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.cloud_run_image

      ports {
        container_port = 8080
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.gcp_project_id
      }

      env {
        name  = "DB_HOST"
        value = google_sql_database_instance.main.private_ip_address
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_USER"
        value = var.db_user
      }

      env {
        name  = "DB_SECRET_NAME"
        value = google_secret_manager_secret.db_password.secret_id
      }

      env {
        name  = "CLOUD_SQL_CONNECTION_NAME"
        value = google_sql_database_instance.main.connection_name
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        http_get {
          path = "/health"
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
        }
        period_seconds = 30
      }
    }
  }

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}

# Allow unauthenticated access to Cloud Run (traffic comes through API Gateway / LB)
resource "google_cloud_run_v2_service_iam_member" "web_api_invoker" {
  project  = var.gcp_project_id
  location = var.gcp_region
  name     = google_cloud_run_v2_service.web_api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
