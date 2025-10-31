output "notification_channel_id" {
  description = "The ID of the monitoring notification channel for email alerts"
  value       = google_monitoring_notification_channel.email.id
}
