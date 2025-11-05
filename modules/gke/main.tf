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
    evaluation_mode = "DISABLED"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  deletion_protection = false

  # Cost allocation and management
  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  # Cost optimization: Cluster autoscaler
  cluster_autoscaling {
    enabled = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    resource_limits {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 100
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 1
      maximum       = 200
    }
  }

  # Enable VPA for cost optimization
  vertical_pod_autoscaling {
    enabled = true
  }

  # Cost optimization: Node auto-provisioning
  node_pool_auto_config {
    network_tags {
      tags = ["gke-node", var.environment]
    }
  }
}

# Spot node pool - DEFAULT for cost savings (70% cheaper)
resource "google_container_node_pool" "spot" {
  name     = "${var.cluster_name}-spot"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = 0
    max_node_count = 20
    location_policy = "ANY"
  }

  node_config {
    machine_type = var.machine_type # Cost-effective
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"
    preemptible  = false
    spot         = true
    image_type   = "COS_CONTAINERD"

    labels = {
      workload-type = "spot"
      cost-center   = "general"
    }

    # NO taint - spot is default for all workloads

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
    min_node_count = 0
    max_node_count = 5
    location_policy = "ANY"
  }

  node_config {
    machine_type = "n2-standard-2" # Better performance
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"
    spot         = false
    image_type   = "COS_CONTAINERD"

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


