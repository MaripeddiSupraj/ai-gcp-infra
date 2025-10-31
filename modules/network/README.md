# Network Module

This module creates a VPC network and subnet with secondary IP ranges for GKE pods and services.

## Features

- VPC network with auto-create subnets disabled for better control
- Subnet with private Google access enabled
- Secondary IP ranges for GKE pods and services
- VPC Flow Logs enabled for network monitoring and security auditing

## Usage

```hcl
module "network" {
  source = "../../modules/network"

  project_id    = "my-gcp-project"
  network_name  = "gke-network"
  subnet_name   = "gke-subnet"
  subnet_cidr   = "10.0.0.0/24"
  region        = "us-central1"
  pods_cidr     = "10.1.0.0/16"
  services_cidr = "10.2.0.0/16"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID where the network resources will be created | `string` | n/a | yes |
| network_name | The name of the VPC network | `string` | n/a | yes |
| subnet_name | The name of the subnet | `string` | n/a | yes |
| subnet_cidr | The CIDR range for the subnet (e.g., 10.0.0.0/24) | `string` | n/a | yes |
| region | The GCP region where the subnet will be created | `string` | n/a | yes |
| pods_cidr | The secondary CIDR range for GKE pods (e.g., 10.1.0.0/16) | `string` | n/a | yes |
| services_cidr | The secondary CIDR range for GKE services (e.g., 10.2.0.0/16) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| network_name | The name of the VPC network |
| network_id | The ID of the VPC network |
| subnet_name | The name of the subnet |
| subnet_id | The ID of the subnet |

## Security Considerations

- VPC Flow Logs are enabled by default with 50% sampling rate for cost optimization
- Private Google Access is enabled for secure access to Google APIs
- Secondary IP ranges are configured for GKE network isolation
