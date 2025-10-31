output "global_ip" {
  description = "The global IP address allocated for the load balancer"
  value       = google_compute_global_address.default.address
}

output "url_map_id" {
  description = "The ID of the URL map resource"
  value       = google_compute_url_map.default.id
}

output "backend_service_id" {
  description = "The ID of the backend service"
  value       = google_compute_backend_service.default.id
}
