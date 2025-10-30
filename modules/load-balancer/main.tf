# Global IP Address
resource "google_compute_global_address" "default" {
  name    = "${var.lb_name}-ip"
  project = var.project_id
}

# SSL Certificate (managed)
resource "google_compute_managed_ssl_certificate" "default" {
  count   = var.enable_ssl ? 1 : 0
  name    = "${var.lb_name}-cert"
  project = var.project_id

  managed {
    domains = var.domains
  }
}

# Backend Service
resource "google_compute_backend_service" "default" {
  name                  = "${var.lb_name}-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = var.enable_cdn
  health_checks         = [google_compute_health_check.default.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group                 = var.neg_id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# Health Check
resource "google_compute_health_check" "default" {
  name    = "${var.lb_name}-health-check"
  project = var.project_id

  http_health_check {
    port         = 8080
    request_path = "/health"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# URL Map
resource "google_compute_url_map" "default" {
  name            = "${var.lb_name}-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.default.id
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "default" {
  name    = "${var.lb_name}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.default.id
}

# HTTPS Proxy
resource "google_compute_target_https_proxy" "default" {
  count            = var.enable_ssl ? 1 : 0
  name             = "${var.lb_name}-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default[0].id]
}

# Forwarding Rule (HTTP)
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.lb_name}-http"
  project               = var.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.id
  ip_address            = google_compute_global_address.default.id
}

# Forwarding Rule (HTTPS)
resource "google_compute_global_forwarding_rule" "https" {
  count                 = var.enable_ssl ? 1 : 0
  name                  = "${var.lb_name}-https"
  project               = var.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.default[0].id
  ip_address            = google_compute_global_address.default.id
}
