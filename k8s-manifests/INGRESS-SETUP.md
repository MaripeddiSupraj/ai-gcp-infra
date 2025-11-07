# Ingress Controller Setup

## Purpose
Nginx Ingress Controller for routing user requests to session-specific pods with session affinity.

## Installation

### 1. Add Helm Repository
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

### 2. Install Nginx Ingress Controller
```bash
kubectl create namespace ingress-nginx

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --values k8s-manifests/ingress-nginx-values.yaml \
  --version 4.8.0
```

### 3. Wait for LoadBalancer IP
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller -w
```

### 4. Get External IP
```bash
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"
```

### 5. Configure DNS (Optional)
```bash
# Point your domain to the Ingress IP
# Example: chat.example.com -> $INGRESS_IP
```

## Features

### Session Affinity
- Routes requests with same session-uuid cookie to same pod
- Maintains user session across requests
- Automatic failover if pod dies

### Autoscaling
- Min replicas: 1
- Max replicas: 5
- Scales based on CPU (70%) and Memory (80%)

### Monitoring
- Prometheus metrics enabled
- ServiceMonitor for automatic scraping
- Grafana dashboards available

## Usage

### Apply Ingress Rules
```bash
kubectl apply -f k8s-manifests/ingress-nginx.yaml
```

### Test Ingress
```bash
# Test session routing
curl -H "Host: chat.example.com" http://$INGRESS_IP/session/create

# Test with session cookie
curl -H "Host: chat.example.com" \
  -H "Cookie: session-uuid=test-123" \
  http://$INGRESS_IP/chat
```

## Cost

| Component | Resources | Monthly Cost |
|-----------|-----------|--------------|
| Ingress Controller | 2 replicas, 500m CPU, 512Mi RAM | ~$25 |
| LoadBalancer | External IP | ~$20 |
| **Total** | | **~$45/month** |

## Uninstall

```bash
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx
```
