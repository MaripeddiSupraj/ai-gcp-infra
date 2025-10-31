# ai-gcp-infra

Production-grade GCP infrastructure with Terraform and Kubernetes.

## Features

✅ **Cost-Optimized GKE Cluster**
- Mixed node pools: Spot (70% cheaper) + On-demand
- Cluster autoscaling: 2-20 spot nodes, 1-5 on-demand nodes
- Estimated cost: $125-875/month based on load

✅ **Production-Ready Autoscaling**
- Horizontal Pod Autoscaler (HPA): CPU + Memory based scaling
- Fast scale-up: Handle traffic spikes in 30 seconds
- Vertical Pod Autoscaler (VPA): Optimize resource requests
- Node pool autoscaling: Automatic capacity management

✅ **High Availability & Security**
- Workload Identity for secure GCP access
- Binary Authorization for image verification
- Network policies enabled
- Pod disruption budgets for zero-downtime updates
- Shielded nodes with secure boot

## Quick Start

```bash
# Format and validate
make fmt
make validate

# Plan changes
make plan

# Apply (with approval)
make apply

# If state locked
make unlock LOCK_ID=<lock-id-from-error>
```

## Structure

```
environments/dev/     # Dev environment
modules/              # Reusable modules
  ├── gke/           # GKE cluster with spot + on-demand nodes
  ├── network/       # VPC and subnets
  ├── monitoring/    # Cloud Monitoring alerts
  └── security/      # Workload Identity
k8s-examples/        # Kubernetes deployment examples
k8s-manifests/       # Production K8s manifests
.github/workflows/   # CI/CD pipelines
```

## Kubernetes Deployments

See [k8s-examples/README.md](k8s-examples/README.md) for detailed deployment patterns.

### Quick Examples

**Deploy to spot nodes (default, cost-optimized):**
```bash
kubectl apply -f k8s-examples/spot-deployment.yaml
```

**Deploy to on-demand nodes (critical workloads):**
```bash
kubectl apply -f k8s-examples/on-demand-deployment.yaml
```

**Enable production autoscaling:**
```bash
kubectl apply -f k8s-examples/hpa-production.yaml
```

## Workflows

- **Docker**: Build, scan, push on app changes
- **Terraform**: Plan on PR, apply on main (requires approval)

## Cost

- Spot nodes: ~$25/month per node (default)
- On-demand: ~$75/month per node (critical only)
- Total: ~$125-875/month based on autoscaling

## Autoscaling for Traffic Spikes

The cluster automatically handles sudden traffic increases:

1. **HPA scales pods**: Doubles capacity in 30 seconds
2. **Cluster autoscaler adds nodes**: 1-3 minutes
3. **Gradual scale-down**: 5-minute stabilization after traffic subsides

Example: Can scale from 3 pods on 2 nodes to 50 pods on 25 nodes automatically.

## State Lock Prevention

✅ **Already fixed:**
- GitHub Actions: Concurrency control prevents simultaneous runs
- Local: Use `make plan/apply` commands (handles cleanup)

**If locked:** `make unlock LOCK_ID=<id>`
