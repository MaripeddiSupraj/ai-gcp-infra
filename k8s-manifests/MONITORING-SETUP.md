# Prometheus & Grafana Monitoring Setup

## Architecture

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards  
- **Kube State Metrics**: Kubernetes object metrics
- **Node Exporter**: Node-level metrics
- **ServiceMonitor**: Auto-discovery of services

## Quick Setup

### 1. Add Helm Repository
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. Create Namespace
```bash
kubectl apply -f k8s-manifests/monitoring-namespace.yaml
```

### 3. Install kube-prometheus-stack
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f k8s-manifests/prometheus-values.yaml \
  --version 55.0.0
```

### 4. Wait for Pods to be Ready
```bash
kubectl get pods -n monitoring -w
```

### 5. Get Grafana LoadBalancer IP
```bash
kubectl get svc -n monitoring prometheus-grafana
```

### 6. Access Grafana
- URL: `http://<EXTERNAL-IP>`
- Username: `admin`
- Password: `ChangeMe123!` (CHANGE in prometheus-values.yaml before install)

## Pre-configured Dashboards

1. **Kubernetes Cluster Monitoring** (ID: 7249)
   - Overall cluster health
   - Resource usage
   - Node status

2. **Kubernetes Pods** (ID: 6417)
   - Per-pod CPU/Memory
   - Pod restarts
   - Network I/O

3. **Node Exporter** (ID: 1860)
   - Node-level metrics
   - Disk usage
   - Network stats

4. **GKE Cluster** (ID: 12114)
   - GKE-specific metrics
   - Workload performance

## View Pod Metrics

### In Grafana:
1. Go to **Dashboards** → **Kubernetes Pods**
2. Select namespace: `default`
3. Select pod: `ai-environment-*`
4. View:
   - CPU usage per pod
   - Memory usage per pod
   - Network I/O
   - Restart count

### Using Prometheus Queries:
```promql
# CPU usage by pod
rate(container_cpu_usage_seconds_total{namespace="default",pod=~"ai-environment.*"}[5m])

# Memory usage by pod
container_memory_usage_bytes{namespace="default",pod=~"ai-environment.*"}

# Pod restart count
kube_pod_container_status_restarts_total{namespace="default",pod=~"ai-environment.*"}
```

## Monitoring Your Application

The kube-prometheus-stack automatically monitors:
- ✅ Pod CPU/Memory usage
- ✅ Pod network I/O
- ✅ Pod restart counts
- ✅ Container resource limits
- ✅ Node metrics
- ✅ Kubernetes events

No code changes needed!

## Cost Impact

| Component | Resources | Monthly Cost |
|-----------|-----------|--------------|
| Prometheus | 1 CPU, 2Gi RAM | ~$30 |
| Grafana | 500m CPU, 512Mi RAM | ~$12 |
| Kube State Metrics | 100m CPU, 128Mi RAM | ~$3 |
| Node Exporter | 100m CPU, 128Mi RAM | ~$3 |
| Storage (15Gi) | PD-Standard | ~$3 |
| LoadBalancer | Grafana external IP | ~$20 |
| **Total** | | **~$71/month** |

### Cost Optimization:
- Use spot nodes (already configured)
- Reduce retention to 7d: saves ~$5/month
- Disable AlertManager: saves ~$10/month (already disabled)
- Use NodePort instead of LoadBalancer: saves ~$20/month

## Upgrade

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f k8s-manifests/prometheus-values.yaml
```

## Uninstall

```bash
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
```

## Troubleshooting

### Pods not starting:
```bash
kubectl describe pod -n monitoring <pod-name>
kubectl logs -n monitoring <pod-name>
```

### Grafana not accessible:
```bash
kubectl get svc -n monitoring
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Access at http://localhost:3000
```

### Prometheus not scraping:
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Check targets at http://localhost:9090/targets
```
