output "network_name" {
  value = module.network.network_name
}

output "cluster_name" {
  value = var.cluster_type == "standard" ? module.gke_standard[0].cluster_name : module.gke_autopilot[0].cluster_name
}

output "cluster_endpoint" {
  value     = var.cluster_type == "standard" ? module.gke_standard[0].cluster_endpoint : module.gke_autopilot[0].cluster_endpoint
  sensitive = true
}

output "repository_url" {
  value = module.gar.repository_url
}

output "project_id" {
  value       = var.project_id
  description = "GCP Project ID"
}

output "region" {
  value       = var.region
  description = "GCP Region"
}

output "repository_id" {
  value       = var.repository_id
  description = "Artifact Registry Repository ID"
}
