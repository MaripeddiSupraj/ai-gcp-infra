# GKE Autopilot Module

## Cost Optimization Benefits

GKE Autopilot provides maximum cost savings:

- **Pay-per-pod pricing**: Only pay for running pods, not idle nodes
- **No minimum nodes**: Scale to zero when no workloads
- **Automatic bin packing**: Optimal pod placement
- **Built-in VPA**: Automatic resource right-sizing
- **No node management overhead**: Fully managed

## Cost Comparison

| Scenario | Standard GKE | Autopilot | Savings |
|----------|--------------|-----------|---------|
| Idle (no pods) | ~$75/month (min nodes) | $0 | 100% |
| Low traffic | ~$150/month | ~$30/month | 80% |
| Medium traffic | ~$300/month | ~$120/month | 60% |

## Usage

```hcl
module "gke_autopilot" {
  source = "../../modules/gke-autopilot"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region
  network_id   = module.network.network_id
  subnet_id    = module.network.subnet_id
}
```

## Features

- Automatic node provisioning and scaling
- Built-in security hardening
- Vertical Pod Autoscaling enabled
- Workload Identity enabled
- No node pool management required
