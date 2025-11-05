variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "cluster_name" {
  type        = string
  description = "GKE Autopilot cluster name"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "network_id" {
  type        = string
  description = "VPC network ID"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID"
}
