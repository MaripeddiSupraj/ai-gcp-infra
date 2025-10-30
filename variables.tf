variable "project_id" {
  type        = string
  description = "GCP Project ID"
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

variable "node_count" {
  type        = number
  description = "Number of nodes per zone"
  default     = 2
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
