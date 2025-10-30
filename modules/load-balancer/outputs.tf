output "global_ip" {
  value       = google_compute_global_address.default.address
  description = "Global IP address for the load balancer"
}

output "url_map_id" {
  value = google_compute_url_map.default.id
}

output "backend_service_id" {
  value = google_compute_backend_service.default.id
}
