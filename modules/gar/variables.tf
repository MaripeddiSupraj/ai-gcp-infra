variable "project_id" {
  type        = string
  description = "The GCP project ID where the Artifact Registry repository will be created"
}

variable "repository_id" {
  type        = string
  description = "The ID of the Artifact Registry repository"
}

variable "region" {
  type        = string
  description = "The GCP region where the repository will be created"
}

variable "format" {
  type        = string
  default     = "DOCKER"
  description = "The format of the repository (DOCKER, MAVEN, NPM, PYTHON, APT, YUM, etc.)"
}

variable "description" {
  type        = string
  default     = "Docker repository"
  description = "A description for the Artifact Registry repository"
}
