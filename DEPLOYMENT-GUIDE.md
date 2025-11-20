# Deployment Guide - Fresh Setup from Scratch

## Prerequisites
- GCP Project with billing enabled
- `gcloud` CLI installed and authenticated
- `kubectl` installed
- `terraform` >= 1.0 installed

## Step 1: Deploy GCP Infrastructure (Terraform)

```bash
# 1. Set your GCP project
export TF_VAR_project_id="your-gcp-project-id"

# 2. Initialize Terraform
cd environments/dev
terraform init

# 3. Review and apply infrastructure
terraform plan
terraform apply
```

**What gets created:**
- VPC network with subnets
- GKE cluster (Standard or Autopilot)
- Artifact Registry for Docker images
- Monitoring alerts
- Workload Identity for security

## Step 2: Connect to GKE Cluster

```bash
# Get cluster credentials
gcloud container clusters get-credentials <cluster-name> --region us-central1

# Verify connection
kubectl get nodes
```

## Step 3: Install Cluster-Wide Components

### 3.1 Install Nginx Ingress Controller
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

### 3.2 Install Cert-Manager (for SSL)
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### 3.3 Install KEDA (for auto-scaling)
```bash
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.12.0/keda-2.12.0.yaml
```

### 3.4 Create LetsEncrypt ClusterIssuer
```bash
kubectl apply -f k8s-manifests/letsencrypt-issuer.yaml
```

## Step 4: Build and Push Docker Images

### 4.1 Build Session Manager
```bash
cd session-manager
docker buildx build --platform linux/amd64 -t us-central1-docker.pkg.dev/<project-id>/docker-repo/session-manager:latest .
docker push us-central1-docker.pkg.dev/<project-id>/docker-repo/session-manager:latest
```

### 4.2 Build AI Environment (User Pod)
```bash
cd ../app
docker buildx build --platform linux/amd64 -t us-central1-docker.pkg.dev/<project-id>/docker-repo/ai-environment:latest .
docker push us-central1-docker.pkg.dev/<project-id>/docker-repo/ai-environment:latest
```

## Step 5: Deploy Fresh System Stack

```bash
# Deploy complete system in fresh-system namespace
kubectl apply -f k8s-manifests/fresh-namespace-stack.yaml

# Deploy cross-namespace RBAC
kubectl apply -f k8s-manifests/fresh-cross-namespace-rbac.yaml

# Deploy KEDA trigger authentication
kubectl apply -f k8s-manifests/fresh-keda.yaml
```

**What gets deployed:**
- `fresh-system` namespace
- Redis (1 replica) - queue management
- Session Manager (2 replicas) - API server
- Secrets (API key, Redis credentials)
- Backup PVC (20Gi) - for user data backups
- ServiceAccount + RBAC - minimal permissions
- LoadBalancer service - external access

## Step 6: Get External IP and Update DNS

```bash
# Get LoadBalancer IP
kubectl get svc session-manager-lb -n fresh-system

# Output example:
# NAME                  TYPE           EXTERNAL-IP      PORT(S)
# session-manager-lb    LoadBalancer   136.119.229.69   80:30123/TCP
```

**Update DNS records:**
- Point your domain to the LoadBalancer IP
- Example: `*.preview.yourdomain.com` → `136.119.229.69`

## Step 7: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n fresh-system

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# redis-0                           1/1     Running   0          5m
# session-manager-xxxxxxxxx-xxxxx   1/1     Running   0          5m
# session-manager-xxxxxxxxx-xxxxx   1/1     Running   0          5m

# Test API endpoint
curl -X POST http://<EXTERNAL-IP>/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}'
```

## Step 8: Update API Key (Production)

```bash
# Generate secure API key
NEW_API_KEY=$(openssl rand -base64 32)

# Update secret
kubectl create secret generic fresh-api-credentials \
  --from-literal=api-key="$NEW_API_KEY" \
  -n fresh-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart session-manager to pick up new key
kubectl rollout restart deployment session-manager -n fresh-system
```

## Deployment Order Summary

1. **Terraform** → GCP infrastructure (VPC, GKE, GAR)
2. **kubectl** → Connect to cluster
3. **Nginx Ingress** → Cluster-wide ingress controller
4. **Cert-Manager** → Cluster-wide SSL management
5. **KEDA** → Cluster-wide auto-scaling
6. **LetsEncrypt** → Cluster-wide SSL issuer
7. **Docker Build** → Session Manager + AI Environment images
8. **Fresh Stack** → Application deployment (Redis, Session Manager, RBAC)
9. **DNS** → Point domain to LoadBalancer IP
10. **API Key** → Update for production security

## Files Reference

| File | Purpose |
|------|---------|
| `environments/dev/main.tf` | Terraform infrastructure |
| `k8s-manifests/fresh-namespace-stack.yaml` | Complete system deployment |
| `k8s-manifests/fresh-cross-namespace-rbac.yaml` | Cross-namespace permissions |
| `k8s-manifests/fresh-keda.yaml` | KEDA auto-scaling config |
| `session-manager/app.py` | Session Manager API code |
| `app/` | User pod AI environment code |

## Troubleshooting

**Pods not starting:**
```bash
kubectl describe pod <pod-name> -n fresh-system
kubectl logs <pod-name> -n fresh-system
```

**LoadBalancer pending:**
```bash
# Wait 2-5 minutes for GCP to provision
kubectl get svc session-manager-lb -n fresh-system -w
```

**SSL not working:**
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

## 📡 Supported API Endpoints

All endpoints tested and production-ready:

### Public Endpoints
```bash
# Health check (no auth required)
curl http://<LOADBALANCER-IP>/health
```

### Authenticated Endpoints
All require `X-API-Key` header:

```bash
# 1. Create session
curl -X POST http://<IP>/session/create \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user@example.com"}'

# 2. Get session status
curl http://<IP>/session/{uuid}/status \
  -H "X-API-Key: your-api-key"

# 3. Sleep session (scale to 0)
curl -X POST http://<IP>/session/{uuid}/sleep \
  -H "X-API-Key: your-api-key"

# 4. Wake session (scale to 1)
curl -X POST http://<IP>/session/{uuid}/wake \
  -H "X-API-Key: your-api-key"

# 5. Scale resources
curl -X POST http://<IP>/session/{uuid}/scale \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"scale": "up"}'

# 6. Send chat message
curl -X POST http://<IP>/session/{uuid}/chat \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello"}'

# 7. Delete session
curl -X DELETE http://<IP>/session/{uuid} \
  -H "X-API-Key: your-api-key"

# 8. List all sessions (admin)
curl http://<IP>/sessions \
  -H "X-API-Key: your-api-key"

# 9. Get metrics
curl http://<IP>/metrics
```

### API Features
- ✅ API Key authentication
- ✅ Rate limiting (100 req/min)
- ✅ Auto-scaling (KEDA)
- ✅ Persistent storage
- ✅ Automatic backups
- ✅ SSL/TLS support
- ✅ Multi-user isolation

For detailed API documentation, see [CLIENT-HANDOVER.md](CLIENT-HANDOVER.md)
