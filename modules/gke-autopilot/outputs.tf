output "cluster_name" {
  value       = google_container_cluster.autopilot.name
  description = "GKE Autopilot cluster name"
}

output "cluster_endpoint" {
  value       = google_container_cluster.autopilot.endpoint
  description = "GKE Autopilot cluster endpoint"
  sensitive   = true
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate
  description = "GKE Autopilot cluster CA certificate"
  sensitive   = true
}
