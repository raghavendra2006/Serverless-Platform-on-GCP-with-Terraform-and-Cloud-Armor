# ============================================================================
# Variables — Enterprise Serverless Platform
# ============================================================================

# ----------------------------------------------------------------------------
# Project-level
# ----------------------------------------------------------------------------

variable "gcp_project_id" {
  description = "The GCP project ID to deploy resources into."
  type        = string
}

variable "gcp_region" {
  description = "The default GCP region for resource deployment."
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "The default GCP zone (used for zonal resources)."
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# ----------------------------------------------------------------------------
# VPC / Networking
# ----------------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the custom VPC network."
  type        = string
  default     = "serverless-vpc"
}

variable "subnet_cidr" {
  description = "CIDR range for the primary subnet."
  type        = string
  default     = "10.10.0.0/24"
}

variable "vpc_connector_cidr" {
  description = "CIDR range for the Serverless VPC Access connector."
  type        = string
  default     = "10.8.0.0/28"
}

# ----------------------------------------------------------------------------
# Cloud SQL
# ----------------------------------------------------------------------------

variable "db_tier" {
  description = "Machine tier for the Cloud SQL instance."
  type        = string
  default     = "db-g1-small"
}

variable "db_name" {
  description = "Name of the PostgreSQL database."
  type        = string
  default     = "platform_db"
}

variable "db_user" {
  description = "Username for the PostgreSQL database."
  type        = string
  default     = "platform_user"
}

variable "db_version" {
  description = "Cloud SQL database version."
  type        = string
  default     = "POSTGRES_15"
}

# ----------------------------------------------------------------------------
# Cloud Armor
# ----------------------------------------------------------------------------

variable "blocked_ip_ranges" {
  description = "List of IP CIDR ranges to block via Cloud Armor."
  type        = list(string)
  default     = ["192.0.2.0/24"]
}

# ----------------------------------------------------------------------------
# Cloud Run
# ----------------------------------------------------------------------------

variable "cloud_run_image" {
  description = "Full container image URI for the Cloud Run web-api service."
  type        = string
  default     = "gcr.io/cloudrun/hello"  # Placeholder — replaced after first build
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances (cold-start mitigation)."
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances."
  type        = number
  default     = 10
}
