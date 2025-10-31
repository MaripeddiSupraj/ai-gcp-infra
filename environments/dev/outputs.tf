output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

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

output "repository_id" {
  value = module.gar.repository_id
}
