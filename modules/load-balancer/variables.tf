variable "project_id" {
  type = string
}

variable "lb_name" {
  type = string
}

variable "neg_id" {
  type        = string
  description = "Network Endpoint Group ID from GKE"
}

variable "enable_ssl" {
  type    = bool
  default = false
}

variable "enable_cdn" {
  type    = bool
  default = true
}

variable "domains" {
  type        = list(string)
  description = "Domains for SSL certificate"
  default     = []
}
