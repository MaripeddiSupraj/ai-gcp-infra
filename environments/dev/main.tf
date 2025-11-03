# Dev environment configuration
# Verifying terraform plan output in PR
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "network" {
  source = "../../modules/network"

  project_id    = var.project_id
  network_name  = var.network_name
  subnet_name   = var.subnet_name
  subnet_cidr   = var.subnet_cidr
  region        = var.region
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}

module "gke_standard" {
  count  = var.cluster_type == "standard" ? 1 : 0
  source = "../../modules/gke"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region
  network_id   = module.network.network_id
  subnet_id    = module.network.subnet_id
  machine_type = var.machine_type
  disk_size_gb = var.disk_size_gb
  environment  = var.environment
}

module "gke_autopilot" {
  count  = var.cluster_type == "autopilot" ? 1 : 0
  source = "../../modules/gke-autopilot"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region
  network_id   = module.network.network_id
  subnet_id    = module.network.subnet_id
}

module "gar" {
  source = "../../modules/gar"

  project_id    = var.project_id
  repository_id = var.repository_id
  region        = var.region
  format        = var.gar_format
  description   = var.gar_description
}

# Temporarily disabled - enable after GKE cluster is created
# module "monitoring" {
#   source = "../../modules/monitoring"
#
#   project_id  = var.project_id
#   alert_email = var.alert_email
# }

module "workload_identity" {
  source = "../../modules/security"

  project_id           = var.project_id
  service_account_name = "app-workload-identity"
  namespace            = "default"
  k8s_service_account  = "app-sa"
  iam_roles            = var.workload_identity_roles
}

module "github_actions_wi" {
  source = "../../modules/wi-federation"

  project_id                   = var.project_id
  pool_id                      = "github-actions-pool-v2"
  pool_display_name            = "GitHub Actions Pool V2"
  provider_id                  = "github-actions-provider-v2"
  provider_display_name        = "GitHub Actions Provider"
  service_account_id           = "github-actions-sa"
  service_account_display_name = "GitHub Actions Service Account"
  project_iam_roles            = var.github_actions_iam_roles
  github_repository            = var.github_repository
}

