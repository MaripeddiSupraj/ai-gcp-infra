resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notification"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "pod_restart" {
  display_name = "High Pod Restart Rate"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Pod restart rate > 5 in 5 minutes"
    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/container/restart_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

resource "google_monitoring_alert_policy" "node_cpu" {
  display_name = "High Node CPU Usage"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Node CPU > 80%"
    condition_threshold {
      filter          = "resource.type=\"k8s_node\" AND metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

resource "google_monitoring_alert_policy" "spot_preemption" {
  display_name = "Spot Instance Preemption"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Spot node preempted"
    condition_threshold {
      filter          = "resource.type=\"k8s_node\" AND metric.type=\"kubernetes.io/node/preemptible\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}
