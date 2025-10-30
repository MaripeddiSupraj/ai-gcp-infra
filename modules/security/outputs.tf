output "service_account_email" {
  value = google_service_account.workload_identity.email
}

output "service_account_name" {
  value = google_service_account.workload_identity.name
}
