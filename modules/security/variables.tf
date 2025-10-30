variable "project_id" {
  type = string
}

variable "service_account_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "k8s_service_account" {
  type = string
}

variable "iam_roles" {
  type    = list(string)
  default = []
}
