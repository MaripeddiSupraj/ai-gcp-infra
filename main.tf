terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "hyperbola-476507-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "network" {
  source = "./modules/network"

  project_id    = var.project_id
  network_name  = var.network_name
  subnet_name   = var.subnet_name
  subnet_cidr   = var.subnet_cidr
  region        = var.region
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}

module "gke" {
  source = "./modules/gke"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region
  network_id   = module.network.network_id
  subnet_id    = module.network.subnet_id
  node_count   = var.node_count
  machine_type = var.machine_type
  disk_size_gb = var.disk_size_gb
}

module "gar" {
  source = "./modules/gar"

  project_id    = var.project_id
  repository_id = var.repository_id
  region        = var.region
  format        = var.gar_format
  description   = var.gar_description
}
