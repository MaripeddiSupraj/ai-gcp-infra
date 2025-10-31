output "service_account_email" {
  description = "The email address of the workload identity service account"
  value       = google_service_account.workload_identity.email
}

output "service_account_name" {
  description = "The fully-qualified name of the workload identity service account"
  value       = google_service_account.workload_identity.name
}
