variable "project_id" {
  type        = string
  description = "The GCP project ID where the load balancer will be created"
}

variable "lb_name" {
  type        = string
  description = "The name prefix for the load balancer resources"
}

variable "neg_id" {
  type        = string
  description = "Network Endpoint Group ID from GKE to use as backend"
}

variable "enable_ssl" {
  type        = bool
  default     = false
  description = "Whether to enable SSL/HTTPS with managed certificate"
}

variable "enable_cdn" {
  type        = bool
  default     = true
  description = "Whether to enable Cloud CDN for content caching"
}

variable "domains" {
  type        = list(string)
  description = "List of domains for the managed SSL certificate"
  default     = []
}
