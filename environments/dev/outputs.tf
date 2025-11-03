output "project_id" {
  description = "The GCP project ID where resources are deployed"
  value       = var.project_id
}

output "region" {
  description = "The GCP region where resources are deployed"
  value       = var.region
}

output "network_name" {
  description = "The name of the VPC network created"
  value       = module.network.network_name
}

output "cluster_name" {
  description = "The name of the GKE cluster (either standard or autopilot)"
  value       = var.cluster_type == "standard" ? module.gke_standard[0].cluster_name : module.gke_autopilot[0].cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint of the GKE cluster (marked sensitive)"
  value       = var.cluster_type == "standard" ? module.gke_standard[0].cluster_endpoint : module.gke_autopilot[0].cluster_endpoint
  sensitive   = true
}

output "repository_url" {
  description = "The full URL to push images to the Artifact Registry repository"
  value       = module.gar.repository_url
}

output "repository_id" {
  description = "The ID of the Artifact Registry repository"
  value       = module.gar.repository_id
}
# Test TF push


# Verify no changes
# Run 1
