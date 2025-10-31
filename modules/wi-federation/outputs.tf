
output "workload_identity_pool_id" {
  value = google_iam_workload_identity_pool.pool.workload_identity_pool_id
}

output "workload_identity_pool_provider_id" {
  value = google_iam_workload_identity_pool_provider.provider.workload_identity_pool_provider_id
}

output "service_account_email" {
  value = google_service_account.sa.email
}
