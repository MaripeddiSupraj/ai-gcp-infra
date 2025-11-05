resource "google_container_cluster" "autopilot" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  enable_autopilot = true

  network    = var.network_id
  subnetwork = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel {
    channel = "REGULAR"
  }

  # Autopilot automatically enables Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Autopilot automatically enables VPA
  vertical_pod_autoscaling {
    enabled = true
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  deletion_protection = false

  resource_labels = {
    environment = "autopilot"
    managed_by  = "terraform"
    cost_model  = "pay-per-pod"
  }
}
