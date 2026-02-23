# ============================================================================
# Cloud Armor — WAF & DDoS Protection
# ============================================================================

# Security policy with deny rule
resource "google_compute_security_policy" "main" {
  name        = "platform-security-policy-${var.environment}"
  description = "Cloud Armor security policy for the serverless platform (${var.environment})"

  # Default rule — allow all traffic
  rule {
    action   = "allow"
    priority = 2147483647

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }

    description = "Default allow rule"
  }

  # Block specific IP ranges (e.g., test/documentation range)
  dynamic "rule" {
    for_each = length(var.blocked_ip_ranges) > 0 ? [1] : []

    content {
      action   = "deny(403)"
      priority = 1000

      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.blocked_ip_ranges
        }
      }

      description = "Block suspicious IP ranges"
    }
  }

  # Block common web attacks (XSS)
  rule {
    action   = "deny(403)"
    priority = 2000

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }

    description = "Block cross-site scripting (XSS) attacks"
  }

  # Block SQL injection attacks
  rule {
    action   = "deny(403)"
    priority = 2100

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }

    description = "Block SQL injection attacks"
  }

  # Rate limiting rule
  rule {
    action   = "throttle"
    priority = 3000

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }

    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"

      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
    }

    description = "Rate limit — 100 requests per minute per IP"
  }
}

# ----------------------------------------------------------------------------
# Global Load Balancer with Cloud Armor
# ----------------------------------------------------------------------------

# Static external IP for the load balancer
resource "google_compute_global_address" "lb_ip" {
  name = "platform-lb-ip-${var.environment}"
}

# Serverless NEG for Cloud Run
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "cloud-run-neg-${var.environment}"
  region                = var.gcp_region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.web_api.name
  }
}

# Backend service with Cloud Armor attached
resource "google_compute_backend_service" "main" {
  name                  = "platform-backend-${var.environment}"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL"
  security_policy       = google_compute_security_policy.main.self_link

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL map
resource "google_compute_url_map" "main" {
  name            = "platform-url-map-${var.environment}"
  default_service = google_compute_backend_service.main.id
}

# HTTP proxy
resource "google_compute_target_http_proxy" "main" {
  name    = "platform-http-proxy-${var.environment}"
  url_map = google_compute_url_map.main.id
}

# Global forwarding rule
resource "google_compute_global_forwarding_rule" "main" {
  name       = "platform-forwarding-rule-${var.environment}"
  target     = google_compute_target_http_proxy.main.id
  port_range = "80"
  ip_address = google_compute_global_address.lb_ip.address
}
