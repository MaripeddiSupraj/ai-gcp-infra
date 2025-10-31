variable "project_id" {
  type        = string
  description = "The GCP project ID where the workload identity service account will be created"
}

variable "service_account_name" {
  type        = string
  description = "The name (account_id) of the service account for workload identity"
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace where the workload identity will be used"
}

variable "k8s_service_account" {
  type        = string
  description = "The name of the Kubernetes service account to bind with GCP service account"
}

variable "iam_roles" {
  type        = list(string)
  default     = []
  description = "List of IAM roles to grant to the workload identity service account"
}
