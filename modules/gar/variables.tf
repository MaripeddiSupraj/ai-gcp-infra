variable "project_id" {
  type = string
}

variable "repository_id" {
  type = string
}

variable "region" {
  type = string
}

variable "format" {
  type    = string
  default = "DOCKER"
}

variable "description" {
  type    = string
  default = "Docker repository"
}
