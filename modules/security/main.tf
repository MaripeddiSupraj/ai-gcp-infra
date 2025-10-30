resource "google_service_account" "workload_identity" {
  account_id   = var.service_account_name
  display_name = "Workload Identity SA for ${var.namespace}"
  project      = var.project_id
}

resource "google_project_iam_member" "workload_identity_roles" {
  for_each = toset(var.iam_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.workload_identity.email}"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.workload_identity.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.k8s_service_account}]"
}
