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
  validation {
    # Validates common GAR formats - see https://cloud.google.com/artifact-registry/docs/supported-formats
    # Note: This list may need updates when Google adds new formats
    # Remove this validation block if you need to use a newer format not listed here
    condition     = contains(["DOCKER", "MAVEN", "NPM", "PYTHON", "APT", "YUM", "GO", "KFP"], var.format)
    error_message = "The format must be one of: DOCKER, MAVEN, NPM, PYTHON, APT, YUM, GO, KFP. See GAR documentation for all supported formats."
  }
}

variable "description" {
  type        = string
  default     = "Docker repository"
  description = "A description for the Artifact Registry repository"
}
