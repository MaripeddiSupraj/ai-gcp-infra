resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_id
  subnetwork = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  vertical_pod_autoscaling {
    enabled = true
  }

  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    resource_limits {
      resource_type = "cpu"
      minimum       = 2
      maximum       = 20
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 4
      maximum       = 64
    }
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
    managed_prometheus {
      enabled = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  network_policy {
    enabled = true
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  deletion_protection = false

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Backup configuration for disaster recovery
  # Note: Requires GKE Backup API to be enabled
  # lifecycle {
  #   ignore_changes = [node_config]
  # }
}

# On-demand node pool for critical workloads
resource "google_container_node_pool" "on_demand" {
  name     = "${var.cluster_name}-on-demand"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"
    spot         = false

    labels = {
      workload-type = "on-demand"
    }

    taint {
      key    = "workload-type"
      value  = "on-demand"
      effect = "NO_SCHEDULE"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Spot node pool for cost-effective workloads
resource "google_container_node_pool" "spot" {
  name     = "${var.cluster_name}-spot"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"
    spot         = true

    labels = {
      workload-type = "spot"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}
