# ai-gcp-infra

Production-grade Terraform infrastructure for GCP with modular design.

## Infrastructure Components

- **VPC Network**: Custom VPC with subnet and secondary IP ranges for GKE
- **GKE Cluster**: Google Kubernetes Engine with auto-scaling node pool
- **Artifact Registry**: Docker repository for container images

## Structure

```
.
├── modules/
│   ├── network/    # VPC and subnet configuration
│   ├── gke/        # GKE cluster and node pool
│   └── gar/        # Google Artifact Registry
├── app/            # Application code and Dockerfile
├── .github/
│   └── workflows/  # CI/CD pipelines
├── main.tf
├── variables.tf
└── outputs.tf
```

## Prerequisites

- GCP Project with billing enabled
- Terraform >= 1.0
- Required GCP APIs enabled:
  - Compute Engine API
  - Kubernetes Engine API
  - Artifact Registry API

## Setup

1. Copy example variables:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your values:
```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
```

3. Initialize and apply:
```bash
terraform init
terraform plan
terraform apply
```

## GitHub Actions

Four workflows are configured:

1. **terraform-check.yml**: Runs on PRs and pushes
   - Format check
   - Validation
   - TFLint

2. **terraform-plan.yml**: Runs on PRs
   - Shows plan in PR comments

3. **terraform-apply.yml**: Runs on main branch
   - Auto-applies changes

4. **docker-build-push.yml**: Runs on app/ changes
   - Builds Docker image
   - Pushes to Artifact Registry

### Required Secrets

- `GCP_SA_KEY`: GCP Service Account key JSON

### Required Variables

- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_REGION`: GCP region (e.g., us-central1)
- `GAR_REPO_ID`: Artifact Registry repository ID

## Module Usage

Each module can be used independently:

```hcl
module "network" {
  source = "./modules/network"
  
  project_id   = "my-project"
  network_name = "my-network"
  region       = "us-central1"
  # ...
}
```
