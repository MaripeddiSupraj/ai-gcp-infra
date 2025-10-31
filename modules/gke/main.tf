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

  # Disable cluster autoscaling - use node pool autoscaling instead
  cluster_autoscaling {
    enabled = false
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

  deletion_protection = true

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Cost allocation and management
  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  # Private cluster for security (optional - can be enabled via variable)
  # private_cluster_config {
  #   enable_private_nodes    = true
  #   enable_private_endpoint = false
  #   master_ipv4_cidr_block  = "172.16.0.0/28"
  # }

  # master_authorized_networks_config {
  #   cidr_blocks {
  #     cidr_block   = "0.0.0.0/0"
  #     display_name = "All networks"
  #   }
  # }

  # Backup configuration for disaster recovery
  # Note: Requires GKE Backup API to be enabled
  # lifecycle {
  #   ignore_changes = [node_config]
  # }
}

# Spot node pool - DEFAULT for cost savings (70% cheaper)
resource "google_container_node_pool" "spot" {
  name     = "${var.cluster_name}-spot"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = 2
    max_node_count = 20
  }

  node_config {
    machine_type = "e2-medium" # Cost-effective
    disk_size_gb = 50
    disk_type    = "pd-standard"
    spot         = true

    labels = {
      workload-type = "spot"
      cost-center   = "general"
    }

    # Taint spot nodes to ensure workloads explicitly tolerate preemption
    # Note: Terraform uses "NO_SCHEDULE", Kubernetes manifests use "NoSchedule" - both are correct
    taint {
      key    = "workload-type"
      value  = "spot"
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

# On-demand node pool - ONLY for critical workloads
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
    machine_type = "n2-standard-2" # Better performance
    disk_size_gb = 100
    disk_type    = "pd-ssd" # Faster disk
    spot         = false

    labels = {
      workload-type = "on-demand"
      cost-center   = "critical"
    }

    # Taint so only critical pods schedule here
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
