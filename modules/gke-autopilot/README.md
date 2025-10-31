# GKE Autopilot Module

This module creates a Google Kubernetes Engine (GKE) Autopilot cluster with best practices for security and ease of management.

## Features

- **Fully Managed**: Google manages nodes, node pools, scaling, and security patches
- **Pay-per-Pod**: Only pay for the resources your pods request
- **Security**: Workload Identity and Binary Authorization enabled
- **Automatic Updates**: Regular channel for balanced updates
- **Resource Labels**: For cost allocation and organization

## Usage

```hcl
module "gke_autopilot" {
  source = "../../modules/gke-autopilot"

  project_id   = "my-gcp-project"
  cluster_name = "autopilot-cluster"
  region       = "us-central1"
  network_id   = module.network.network_id
  subnet_id    = module.network.subnet_id
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID where the GKE Autopilot cluster will be created | `string` | n/a | yes |
| cluster_name | The name of the GKE Autopilot cluster | `string` | n/a | yes |
| region | The GCP region where the GKE Autopilot cluster will be created | `string` | n/a | yes |
| network_id | The ID of the VPC network for the GKE Autopilot cluster | `string` | n/a | yes |
| subnet_id | The ID of the subnet for the GKE Autopilot cluster | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | The name of the GKE Autopilot cluster |
| cluster_endpoint | The endpoint of the GKE Autopilot cluster (marked sensitive) |
| cluster_ca_certificate | The cluster CA certificate (base64 encoded, marked sensitive) |

## Security Features

- **Workload Identity**: Secure GKE pod authentication with GCP services
- **Binary Authorization**: Enforce deployment policies
- **Automatic Security Patches**: Google automatically patches nodes
- **Resource Labels**: `cluster_type=autopilot` and `managed_by=terraform`

## When to Use

**Use Autopilot when:**
- You want minimal operational overhead
- You have standard workload requirements
- You want predictable, per-pod pricing
- You prefer Google-managed security and updates

**Use Standard GKE when:**
- You need custom node configurations
- You require specific machine types or GPUs
- You need Windows node pools
- You want maximum control over the cluster
