variable "project_id" {
  type        = string
  description = "The GCP project ID where the network resources will be created"
}

variable "network_name" {
  type        = string
  description = "The name of the VPC network"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnet"
}

variable "subnet_cidr" {
  type        = string
  description = "The CIDR range for the subnet (e.g., 10.0.0.0/24)"
}

variable "region" {
  type        = string
  description = "The GCP region where the subnet will be created"
}

variable "pods_cidr" {
  type        = string
  description = "The secondary CIDR range for GKE pods (e.g., 10.1.0.0/16)"
}

variable "services_cidr" {
  type        = string
  description = "The secondary CIDR range for GKE services (e.g., 10.2.0.0/16)"
}
