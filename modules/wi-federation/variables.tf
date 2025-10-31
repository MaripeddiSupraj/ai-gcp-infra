
variable "project_id" {
  type        = string
  description = "The GCP project ID."
}

variable "pool_id" {
  type        = string
  description = "The ID of the Workload Identity Pool."
}

variable "pool_display_name" {
  type        = string
  description = "The display name of the Workload Identity Pool."
}

variable "provider_id" {
  type        = string
  description = "The ID of the Workload Identity Pool Provider."
}

variable "provider_display_name" {
  type        = string
  description = "The display name of the Workload Identity Pool Provider."
}

variable "service_account_id" {
  type        = string
  description = "The ID of the Service Account."
}

variable "service_account_display_name" {
  type        = string
  description = "The display name of the Service Account."
}

variable "project_iam_roles" {
  type        = list(string)
  description = "The IAM roles to grant to the Service Account on the project."
  default     = []
}

variable "github_repository" {
  type        = string
  description = "The GitHub repository in the format 'owner/repo'."
}
