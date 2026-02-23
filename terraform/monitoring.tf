# ============================================================================
# Cloud Monitoring — Alerts & Notifications
# ============================================================================

# Notification channel (email)
resource "google_monitoring_notification_channel" "email" {
  display_name = "Platform Alerts Email (${var.environment})"
  type         = "email"

  labels = {
    email_address = "platform-alerts@example.com"
  }

  depends_on = [google_project_service.required_apis]
}

# Alert policy — Cloud Run 5xx errors
resource "google_monitoring_alert_policy" "cloud_run_5xx" {
  display_name = "Cloud Run 5xx Error Rate (${var.environment})"
  combiner     = "OR"

  conditions {
    display_name = "5xx error rate exceeds threshold"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "The Cloud Run service **web-api-${var.environment}** is returning a high rate of 5xx errors. Refer to the runbook at docs/runbook.md for investigation steps."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.required_apis]
}

# Alert policy — Cloud Function execution errors
resource "google_monitoring_alert_policy" "function_errors" {
  display_name = "Cloud Function Execution Errors (${var.environment})"
  combiner     = "OR"

  conditions {
    display_name = "Function error count exceeds threshold"

    condition_threshold {
      filter          = "resource.type = \"cloud_function\" AND metric.type = \"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status = \"error\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Cloud Functions in the **${var.environment}** environment are experiencing execution errors. Check Cloud Logging for details."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.required_apis]
}

# Alert policy — Cloud SQL high CPU
resource "google_monitoring_alert_policy" "cloudsql_cpu" {
  display_name = "Cloud SQL High CPU Utilization (${var.environment})"
  combiner     = "OR"

  conditions {
    display_name = "CPU utilization > 80%"

    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Cloud SQL instance CPU utilization is above 80%. Consider scaling the instance tier or optimizing queries."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.required_apis]
}
