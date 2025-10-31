output "cluster_name" {
  description = "The name of the GKE Autopilot cluster"
  value       = google_container_cluster.autopilot.name
}

output "cluster_endpoint" {
  description = "The endpoint of the GKE Autopilot cluster (marked sensitive)"
  value       = google_container_cluster.autopilot.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The cluster CA certificate (base64 encoded, marked sensitive)"
  value       = google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate
  sensitive   = true
}
