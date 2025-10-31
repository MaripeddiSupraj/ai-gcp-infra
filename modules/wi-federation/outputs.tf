
output "workload_identity_pool_id" {
  description = "The ID of the Workload Identity Pool for GitHub Actions authentication"
  value       = google_iam_workload_identity_pool.pool.workload_identity_pool_id
}

output "workload_identity_pool_provider_id" {
  description = "The ID of the Workload Identity Pool Provider for GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.provider.workload_identity_pool_provider_id
}

output "service_account_email" {
  description = "The email address of the service account used by GitHub Actions"
  value       = google_service_account.sa.email
}
