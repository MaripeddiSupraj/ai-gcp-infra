resource "google_storage_bucket" "chat_sessions" {
  name          = "${var.project_id}-chat-sessions"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  labels = {
    environment = var.environment
    purpose     = "chat-history"
    managed_by  = "terraform"
  }
}

resource "google_storage_bucket_iam_member" "workload_identity_access" {
  bucket = google_storage_bucket.chat_sessions.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.workload_identity_sa_email}"
}
