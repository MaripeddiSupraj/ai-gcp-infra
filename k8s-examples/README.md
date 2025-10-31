# Kubernetes Deployment Examples

This directory contains production-ready examples for deploying workloads on the GKE cluster with optimal cost and performance.

## Node Types Overview

### Spot Nodes (Default - Cost Optimized)
- **Cost**: ~70% cheaper than on-demand
- **Reliability**: Can be preempted with 30-second notice
- **Use Cases**: Stateless apps, batch jobs, development workloads
- **Min Nodes**: 2, **Max Nodes**: 20
- **Machine Type**: e2-medium

### On-Demand Nodes (Critical Workloads)
- **Cost**: Standard pricing, ~3x more expensive than spot
- **Reliability**: High availability, no preemption
- **Use Cases**: Databases, stateful apps, critical services
- **Min Nodes**: 1, **Max Nodes**: 5
- **Machine Type**: n2-standard-2 with SSD

## Deployment Patterns

### 1. Spot Workload (Default)
Use for general-purpose, fault-tolerant workloads:

```bash
kubectl apply -f spot-deployment.yaml
```

**Key Features:**
- Tolerates spot node taints
- Runs on cost-effective spot instances
- Scales with cluster autoscaler

### 2. On-Demand Workload (Critical)
Use for mission-critical, stateful workloads:

```bash
kubectl apply -f on-demand-deployment.yaml
```

**Key Features:**
- Tolerates on-demand node taints
- Pod anti-affinity for HA
- Higher resource limits

### 3. Production HPA (Autoscaling)
For handling sudden traffic spikes:

```bash
kubectl apply -f hpa-production.yaml
```

**Key Features:**
- Scales based on CPU (70%) and Memory (80%)
- Fast scale-up (immediate, up to 100% increase)
- Gradual scale-down (5 min stabilization)
- Min 3 replicas, Max 50 replicas

## Autoscaling Strategy

### Cluster Autoscaler
- **Enabled**: On both spot and on-demand node pools
- **Spot Pool**: Min 2, Max 20 nodes
- **On-Demand Pool**: Min 1, Max 5 nodes
- Automatically adds nodes when pods can't be scheduled
- Removes underutilized nodes after 10 minutes

### Horizontal Pod Autoscaler (HPA)
- **Metrics**: CPU and Memory utilization
- **Scale-Up**: Immediate when threshold breached
- **Scale-Down**: Gradual with 5-minute stabilization
- See `hpa-production.yaml` for configuration

### Vertical Pod Autoscaler (VPA)
- **Status**: Enabled at cluster level
- **Mode**: Recommendation only (safe for production)
- See `../k8s-manifests/base/vpa.yaml` for examples

## Handling Sudden Traffic

The cluster is configured to handle traffic spikes efficiently:

1. **Fast Pod Scaling**: HPA can double pod count in 30 seconds
2. **Cluster Scaling**: New nodes provisioned in 1-3 minutes
3. **Spot Instances**: Cost-effective scaling for burst traffic
4. **On-Demand Backup**: Critical pods remain stable

### Example: Traffic Spike Scenario
```
Normal load: 3 pods on 2 spot nodes
↓
Traffic spike detected (CPU > 70%)
↓
HPA scales to 6 pods in 30 seconds
↓
If nodes full: Cluster autoscaler adds spot nodes (1-3 min)
↓
Traffic subsides
↓
HPA waits 5 minutes, then scales down gradually
↓
After 10 minutes: Cluster autoscaler removes unused nodes
```

## Best Practices

### Resource Requests and Limits
Always set both for predictable autoscaling:
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Pod Disruption Budgets
Ensure availability during node scaling:
```bash
kubectl apply -f ../k8s-manifests/base/pod-disruption-budget.yaml
```

### Node Selector + Tolerations
For spot nodes:
```yaml
tolerations:
- key: "workload-type"
  operator: "Equal"
  value: "spot"
  effect: "NoSchedule"
nodeSelector:
  workload-type: spot
```

For on-demand nodes:
```yaml
tolerations:
- key: "workload-type"
  operator: "Equal"
  value: "on-demand"
  effect: "NoSchedule"
nodeSelector:
  workload-type: on-demand
```

## Cost Optimization

### Monthly Cost Estimates
- **Spot nodes**: ~$25/node/month × 2-20 nodes = $50-500/month
- **On-demand nodes**: ~$75/node/month × 1-5 nodes = $75-375/month
- **Total range**: $125-875/month (varies with load)

### Optimization Tips
1. Use spot nodes for 80%+ of workloads
2. Set appropriate HPA min/max values
3. Enable cluster autoscaler scale-down
4. Monitor with GCP Cost Management

## Monitoring

View cluster autoscaling events:
```bash
kubectl get events --all-namespaces | grep -i "cluster-autoscaler"
```

View HPA status:
```bash
kubectl get hpa
kubectl describe hpa app-hpa-production
```

View node pool status:
```bash
kubectl get nodes -L workload-type
```

## Additional Resources

- [GKE Autoscaling Best Practices](https://cloud.google.com/kubernetes-engine/docs/concepts/horizontalpodautoscaler)
- [Spot VM Documentation](https://cloud.google.com/compute/docs/instances/spot)
- [Pod Disruption Budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
