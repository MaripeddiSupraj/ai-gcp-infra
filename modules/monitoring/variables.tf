variable "project_id" {
  type        = string
  description = "The GCP project ID where monitoring resources will be created"
}

variable "alert_email" {
  type        = string
  default     = "alerts@example.com"
  description = "Email address to receive monitoring alerts and notifications"
}
