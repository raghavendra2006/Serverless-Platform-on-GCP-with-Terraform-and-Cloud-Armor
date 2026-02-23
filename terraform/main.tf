# ============================================================================
# Enterprise Serverless Platform on GCP — Main Terraform Configuration
# ============================================================================

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.50.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.50.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.0"
    }
  }

  # Remote backend (GCS) — uncomment and configure for production
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "serverless-platform/state"
  # }
}

# ----------------------------------------------------------------------------
# Providers
# ----------------------------------------------------------------------------

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ----------------------------------------------------------------------------
# Enable Required GCP APIs
# ----------------------------------------------------------------------------

resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    "apigateway.googleapis.com",
    "servicecontrol.googleapis.com",
    "servicemanagement.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com",
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
  ])

  project                    = var.gcp_project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

# ----------------------------------------------------------------------------
# Random suffix for globally-unique resource names
# ----------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 4
}

# ----------------------------------------------------------------------------
# Labels applied to all resources
# ----------------------------------------------------------------------------

locals {
  common_labels = {
    project     = "serverless-platform"
    environment = var.environment
    managed_by  = "terraform"
  }
}
