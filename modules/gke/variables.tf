variable "project_id" {
  type        = string
  description = "The GCP project ID where the GKE cluster will be created"
}

variable "cluster_name" {
  type        = string
  description = "The name of the GKE cluster"
}

variable "region" {
  type        = string
  description = "The GCP region where the GKE cluster will be created"
}

variable "network_id" {
  type        = string
  description = "The ID of the VPC network for the GKE cluster"
}

variable "subnet_id" {
  type        = string
  description = "The ID of the subnet for the GKE cluster"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Environment label for the cluster (e.g., production, staging, development)"
}

variable "disk_size_gb" {
  type        = number
  description = "Node disk size in GB"
  default     = 50
}

variable "machine_type" {
  type        = string
  description = "Machine type for nodes"
  default     = "e2-medium"
}
