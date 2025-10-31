output "global_ip" {
  value       = google_compute_global_address.default.address
  description = "The global IP address allocated for the load balancer"
}

output "url_map_id" {
  value       = google_compute_url_map.default.id
  description = "The ID of the URL map resource"
}

output "backend_service_id" {
  value       = google_compute_backend_service.default.id
  description = "The ID of the backend service"
}
