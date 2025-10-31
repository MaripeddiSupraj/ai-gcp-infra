# GKE Standard Module

This module creates a Google Kubernetes Engine (GKE) standard cluster with best practices for security, cost optimization, and reliability.

## Features

- **Cost Optimization**: Two node pools with different pricing models
  - Spot node pool (default, 70% cheaper) for general workloads
  - On-demand node pool for critical workloads
- **Security**: Workload Identity, Binary Authorization, Network Policy, Shielded Nodes
- **Monitoring**: Managed Prometheus, system and workload logging
- **High Availability**: Auto-repair, auto-upgrade, vertical pod autoscaling
- **Modern Configuration**: COS_CONTAINERD image, GKE metadata server

## Usage

```hcl
module "gke_standard" {
  source = "../../modules/gke"

  project_id   = "my-gcp-project"
  cluster_name = "primary-cluster"
  region       = "us-central1"
  network_id   = module.network.network_id
  subnet_id    = module.network.subnet_id
  environment  = "production"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID where the GKE cluster will be created | `string` | n/a | yes |
| cluster_name | The name of the GKE cluster | `string` | n/a | yes |
| region | The GCP region where the GKE cluster will be created | `string` | n/a | yes |
| network_id | The ID of the VPC network for the GKE cluster | `string` | n/a | yes |
| subnet_id | The ID of the subnet for the GKE cluster | `string` | n/a | yes |
| environment | Environment label for the cluster | `string` | `"production"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | The name of the GKE cluster |
| cluster_endpoint | The endpoint of the GKE cluster (marked sensitive) |
| cluster_ca_certificate | The cluster CA certificate (base64 encoded, marked sensitive) |

## Node Pools

### Design Decision: Fixed Node Pool Configurations

This module uses **fixed machine types and disk sizes** for each node pool as part of an opinionated cost optimization strategy:

- **Spot pool**: Fixed at e2-medium with 50GB pd-standard (cost-optimized)
- **On-demand pool**: Fixed at n2-standard-2 with 100GB pd-ssd (performance-optimized)

**Rationale**:
- Simplifies cost estimation and capacity planning
- Encourages using spot instances for most workloads
- Reserves powerful on-demand instances for critical workloads only
- If you need custom machine types, consider forking this module or using the Autopilot variant

### Spot Node Pool (Default)
- **Machine Type**: e2-medium
- **Disk**: 50GB pd-standard
- **Autoscaling**: 2-20 nodes
- **Use Case**: General workloads (no taints)
- **Cost**: ~70% cheaper than on-demand

### On-Demand Node Pool (Critical)
- **Machine Type**: n2-standard-2
- **Disk**: 100GB pd-ssd
- **Autoscaling**: 1-5 nodes
- **Use Case**: Critical workloads only (tainted)
- **Taint**: `workload-type=on-demand:NoSchedule`

To schedule pods on the on-demand node pool:
```yaml
tolerations:
  - key: "workload-type"
    operator: "Equal"
    value: "on-demand"
    effect: "NoSchedule"
```

## Security Features

- **Workload Identity**: Secure GKE pod authentication with GCP services
- **Binary Authorization**: Enforce deployment policies
- **Network Policy**: Pod-to-pod network security
- **Shielded Nodes**: Secure boot and integrity monitoring
- **Security Posture**: Basic security posture with vulnerability scanning
- **Metadata Server**: GKE metadata server enabled, legacy endpoints disabled

## Cost Optimization

- Spot instances by default (70% cost savings)
- Efficient autoscaling (2-20 nodes for spot, 1-5 for on-demand)
- Resource labels for cost allocation and tracking
