variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

variable "workload_identity_sa_email" {
  type        = string
  description = "Workload Identity service account email for bucket access"
}
