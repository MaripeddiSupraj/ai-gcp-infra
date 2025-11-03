variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

variable "region" {
  type        = string
  description = "GCP Region"
  default     = "us-central1"
}

variable "network_name" {
  type        = string
  description = "VPC Network name"
  default     = "gke-network"
}

variable "subnet_name" {
  type        = string
  description = "Subnet name"
  default     = "gke-subnet"
}

variable "subnet_cidr" {
  type        = string
  description = "Subnet CIDR"
  default     = "10.0.0.0/24"
}

variable "pods_cidr" {
  type        = string
  description = "Pods secondary CIDR"
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  type        = string
  description = "Services secondary CIDR"
  default     = "10.2.0.0/16"
}

variable "cluster_name" {
  type        = string
  description = "GKE Cluster name"
  default     = "primary-cluster"
}

variable "cluster_type" {
  type        = string
  description = "GKE cluster type: standard or autopilot"
  default     = "standard"
  validation {
    condition     = contains(["standard", "autopilot"], var.cluster_type)
    error_message = "cluster_type must be either 'standard' or 'autopilot'"
  }
}

variable "machine_type" {
  type        = string
  description = "Machine type for nodes"
  default     = "e2-medium"
}

variable "disk_size_gb" {
  type        = number
  description = "Disk size in GB"
  default     = 50
}

variable "repository_id" {
  type        = string
  description = "Artifact Registry repository ID"
  default     = "docker-repo"
}

variable "gar_format" {
  type        = string
  description = "Artifact Registry format"
  default     = "DOCKER"
}

variable "gar_description" {
  type        = string
  description = "Artifact Registry description"
  default     = "Docker repository for container images"
}

# Temporarily disabled - enable with monitoring module
# variable "alert_email" {
#   type        = string
#   description = "Email for monitoring alerts"
#   default     = "alerts@example.com"
# }

variable "workload_identity_roles" {
  type        = list(string)
  description = "IAM roles for workload identity"
  default     = ["roles/storage.objectViewer"]
}

variable "github_actions_iam_roles" {
  type        = list(string)
  description = "The IAM roles to grant to the GitHub Actions Service Account on the project."
  default = [
    "roles/container.developer",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser"
  ]
}

variable "github_repository" {
  type        = string
  description = "The GitHub repository in the format 'owner/repo'."
}
