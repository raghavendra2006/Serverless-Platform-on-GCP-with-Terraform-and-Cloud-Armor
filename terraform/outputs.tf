# ============================================================================
# Outputs — Enterprise Serverless Platform
# ============================================================================

# ----------------------------------------------------------------------------
# Networking
# ----------------------------------------------------------------------------

output "vpc_network_name" {
  description = "Name of the custom VPC network."
  value       = google_compute_network.main_vpc.name
}

output "vpc_network_self_link" {
  description = "Self-link of the custom VPC network."
  value       = google_compute_network.main_vpc.self_link
}

output "subnet_name" {
  description = "Name of the primary subnet."
  value       = google_compute_subnetwork.main_subnet.name
}

# ----------------------------------------------------------------------------
# Cloud SQL
# ----------------------------------------------------------------------------

output "cloudsql_instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.main.name
}

output "cloudsql_connection_name" {
  description = "Cloud SQL connection name (project:region:instance)."
  value       = google_sql_database_instance.main.connection_name
}

output "cloudsql_private_ip" {
  description = "Private IP of the Cloud SQL instance."
  value       = google_sql_database_instance.main.private_ip_address
}

# ----------------------------------------------------------------------------
# Storage
# ----------------------------------------------------------------------------

output "gcs_bucket_name" {
  description = "Name of the file upload GCS bucket."
  value       = google_storage_bucket.uploads.name
}

# ----------------------------------------------------------------------------
# Cloud Functions
# ----------------------------------------------------------------------------

output "function_upload_url" {
  description = "URL of the file-upload HTTP Cloud Function."
  value       = google_cloudfunctions2_function.file_upload.url
}

output "function_process_name" {
  description = "Name of the file-process Cloud Function."
  value       = google_cloudfunctions2_function.file_process.name
}

# ----------------------------------------------------------------------------
# Cloud Run
# ----------------------------------------------------------------------------

output "cloud_run_url" {
  description = "URL of the Cloud Run web-api service."
  value       = google_cloud_run_v2_service.web_api.uri
}

# ----------------------------------------------------------------------------
# API Gateway
# ----------------------------------------------------------------------------

output "api_gateway_url" {
  description = "Base URL of the API Gateway."
  value       = "https://${google_api_gateway_gateway.main.default_hostname}"
}

# ----------------------------------------------------------------------------
# Security
# ----------------------------------------------------------------------------

output "cloud_armor_policy_name" {
  description = "Name of the Cloud Armor security policy."
  value       = google_compute_security_policy.main.name
}

output "secret_db_password_id" {
  description = "Resource ID of the DB password secret in Secret Manager."
  value       = google_secret_manager_secret.db_password.secret_id
}

# ----------------------------------------------------------------------------
# Load Balancer
# ----------------------------------------------------------------------------

output "load_balancer_ip" {
  description = "External IP of the global load balancer."
  value       = google_compute_global_address.lb_ip.address
}
