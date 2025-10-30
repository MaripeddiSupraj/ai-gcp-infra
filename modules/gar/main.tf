resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.repository_id
  format        = var.format
  project       = var.project_id
  description   = var.description
}
