output "network_name" {
  value = module.network.network_name
}

output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_endpoint" {
  value     = module.gke.cluster_endpoint
  sensitive = true
}

output "repository_url" {
  value = module.gar.repository_url
}
