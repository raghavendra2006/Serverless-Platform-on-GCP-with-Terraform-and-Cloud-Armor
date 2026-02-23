# ============================================================================
# API Gateway — Unified Entry Point
# ============================================================================

resource "google_api_gateway_api" "main" {
  provider = google-beta
  api_id   = "serverless-platform-api-${var.environment}"

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}

resource "google_api_gateway_api_config" "main" {
  provider      = google-beta
  api           = google_api_gateway_api.main.api_id
  api_config_id = "config-${random_id.suffix.hex}"

  openapi_documents {
    document {
      path = "openapi.yaml"
      contents = base64encode(templatefile("${path.module}/templates/openapi.yaml.tpl", {
        function_upload_url = google_cloudfunctions2_function.file_upload.url
        cloud_run_url       = google_cloud_run_v2_service.web_api.uri
        api_title           = "Serverless Platform API (${var.environment})"
      }))
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "main" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.main.id
  gateway_id = "platform-gateway-${var.environment}"
  region     = var.gcp_region

  labels = local.common_labels
}
