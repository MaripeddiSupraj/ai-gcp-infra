output "bucket_name" {
  value       = google_storage_bucket.chat_sessions.name
  description = "Chat sessions bucket name"
}

output "bucket_url" {
  value       = google_storage_bucket.chat_sessions.url
  description = "Chat sessions bucket URL"
}
