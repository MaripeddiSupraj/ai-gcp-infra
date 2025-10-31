variable "project_id" {
  type        = string
  description = "The GCP project ID where the GKE Autopilot cluster will be created"
}

variable "cluster_name" {
  type        = string
  description = "The name of the GKE Autopilot cluster"
}

variable "region" {
  type        = string
  description = "The GCP region where the GKE Autopilot cluster will be created"
}

variable "network_id" {
  type        = string
  description = "The ID of the VPC network for the GKE Autopilot cluster"
}

variable "subnet_id" {
  type        = string
  description = "The ID of the subnet for the GKE Autopilot cluster"
}
