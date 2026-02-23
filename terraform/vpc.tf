# ============================================================================
# VPC Network & Subnets
# ============================================================================

# Custom VPC — no auto-created subnets
resource "google_compute_network" "main_vpc" {
  name                    = "${var.vpc_name}-${var.environment}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  project                 = var.gcp_project_id

  depends_on = [google_project_service.required_apis]
}

# Primary subnet
resource "google_compute_subnetwork" "main_subnet" {
  name                     = "${var.vpc_name}-subnet-${var.environment}"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.gcp_region
  network                  = google_compute_network.main_vpc.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ----------------------------------------------------------------------------
# Private Services Access (for Cloud SQL private IP)
# ----------------------------------------------------------------------------

resource "google_compute_global_address" "private_ip_range" {
  name          = "private-ip-range-${var.environment}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  depends_on = [google_project_service.required_apis]
}

# ----------------------------------------------------------------------------
# Serverless VPC Access Connector
# ----------------------------------------------------------------------------

resource "google_vpc_access_connector" "main" {
  name          = "vpc-connector-${var.environment}"
  region        = var.gcp_region
  ip_cidr_range = var.vpc_connector_cidr
  network       = google_compute_network.main_vpc.name
  min_instances = 2
  max_instances = 3

  depends_on = [google_project_service.required_apis]
}

# ----------------------------------------------------------------------------
# Firewall Rules
# ----------------------------------------------------------------------------

# Allow internal traffic within the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-${var.environment}"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr]
  priority      = 1000
}

# Allow health check probes from GCP load balancers
resource "google_compute_firewall" "allow_health_checks" {
  name    = "allow-health-checks-${var.environment}"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  # Google Cloud health check IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  priority      = 900
}

# Deny all other ingress by default
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "deny-all-ingress-${var.environment}"
  network = google_compute_network.main_vpc.name

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  priority      = 65534
}
