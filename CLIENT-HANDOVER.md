# Client Handover Document - AI Session Manager

## System Overview

**Production-ready multi-user AI workspace platform** with auto-scaling, persistent storage, and automated backups.

### Architecture
- **Session Manager**: Flask API (2 replicas) managing user sessions
- **Redis**: Queue management for async operations
- **User Pods**: Isolated VS Code environments per user (auto-scale 0→1→0)
- **KEDA**: Auto-scaling based on Redis queue depth
- **Nginx Ingress**: SSL termination and routing
- **Persistent Storage**: 5Gi PVC per user + 20Gi backup PVC

### Current Deployment
- **Namespace**: `fresh-system`
- **LoadBalancer IP**: `136.119.229.69`
- **API Endpoint**: `http://136.119.229.69`
- **Domain Pattern**: `https://vs-code-{uuid}.preview.hyperbola.in`
- **API Key**: `your-secure-api-key-change-in-production` (⚠️ CHANGE IN PRODUCTION)

---

## API Documentation

### Base URL
```
http://136.119.229.69
```

### Authentication
All endpoints require API key in header:
```
X-API-Key: your-secure-api-key-change-in-production
```

### Rate Limits
- 100 requests per minute per IP

---

## API Endpoints

### 1. Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "3.2.0",
  "redis": "connected",
  "timestamp": "2025-11-20T13:05:37.533544"
}
```

---

### 2. Create Session
```http
POST /session/create
Content-Type: application/json
X-API-Key: your-secure-api-key-change-in-production

{
  "user_id": "user@example.com"
}
```

**Response:**
```json
{
  "uuid": "0fa6debc",
  "user_id": "user@example.com",
  "status": "created",
  "workspace_url": "https://vs-code-0fa6debc.preview.hyperbola.in",
  "created_at": "2025-11-20T13:05:20.884405"
}
```

**What happens:**
- Creates Kubernetes Deployment (1 replica)
- Creates Service (ClusterIP)
- Creates Ingress (SSL + domain)
- Creates PVC (5Gi persistent storage)
- Creates KEDA ScaledObject (auto-scaling)
- Pod starts immediately with VS Code environment

**Timing:** ~20-30 seconds for pod to be ready

---

### 3. Get Session Status
```http
GET /session/{uuid}
X-API-Key: your-secure-api-key-change-in-production
```

**Response:**
```json
{
  "uuid": "0fa6debc",
  "session": {
    "user_id": "user@example.com",
    "status": "created",
    "created_at": "2025-11-20T13:05:20.881362",
    "last_activity": "2025-11-20T13:05:20.881372"
  },
  "replicas": 1,
  "queue_length": 0,
  "timestamp": "2025-11-20T13:05:37.533544"
}
```

---

### 4. Sleep Session (Scale to 0)
```http
POST /session/{uuid}/sleep
X-API-Key: your-secure-api-key-change-in-production
```

**Response:**
```json
{
  "uuid": "0fa6debc",
  "action": "sleep",
  "status": "sleeping",
  "message": "Pod queued for sleep"
}
```

**What happens:**
- Scales deployment to 0 replicas
- Preserves PVC data
- Reduces costs (no compute charges)

**Timing:** ~10-15 seconds

---

### 5. Wake Session (Scale to 1)
```http
POST /session/{uuid}/wake
X-API-Key: your-secure-api-key-change-in-production
```

**Response:**
```json
{
  "uuid": "0fa6debc",
  "action": "wake",
  "status": "waking"
}
```

**What happens:**
- Scales deployment to 1 replica
- Restores all data from PVC
- Pod becomes ready in ~20-30 seconds

---

### 6. Scale Up (Manual)
```http
POST /session/{uuid}/scale-up
X-API-Key: your-secure-api-key-change-in-production
```

**Response:**
```json
{
  "uuid": "0fa6debc",
  "action": "scale_up",
  "status": "success",
  "message": "Pod scaled up"
}
```

---

### 7. Scale Down (Manual)
```http
POST /session/{uuid}/scale-down
X-API-Key: your-secure-api-key-change-in-production
```

**Response:**
```json
{
  "uuid": "0fa6debc",
  "action": "scale_down",
  "status": "success",
  "message": "Pod scaled down"
}
```

---

### 8. Delete Session
```http
DELETE /session/{uuid}
X-API-Key: your-secure-api-key-change-in-production
```

**Response:**
```json
{
  "uuid": "0fa6debc",
  "status": "terminated",
  "message": "Session and all resources deleted"
}
```

**What happens:**
1. Creates backup job (zips /app directory to backup PVC)
2. Deletes Deployment
3. Deletes Service
4. Deletes Ingress
5. Deletes PVC (after backup completes)
6. Deletes KEDA ScaledObject
7. Removes Redis session data

**Backup location:** `/mnt/backup/workspace-{uuid}-{timestamp}.zip`

---

## Auto-Scaling Behavior (KEDA)

### Configuration
- **Min Replicas**: 0 (scales to zero when idle)
- **Max Replicas**: 1 (one pod per user)
- **Cooldown Period**: 300 seconds (5 minutes)
- **Trigger**: Redis queue length > 0

### How it works
1. User creates session → Pod starts immediately (replicas=1)
2. User calls `/sleep` → Pod scales to 0 after cooldown
3. User calls `/wake` → Pod scales to 1
4. KEDA monitors Redis queue → Auto-scales based on pending tasks

---

## Resource Specifications

### Session Manager
- **Replicas**: 2 (high availability)
- **Resources**: 256Mi-512Mi RAM, 250m-500m CPU
- **Image**: `us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/session-manager:latest`

### User Pods
- **Replicas**: 0-1 (auto-scaled)
- **Resources**: 256Mi-512Mi RAM, 250m-500m CPU
- **Image**: `us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:latest`
- **Storage**: 5Gi PVC per user (standard-rwo)

### Redis
- **Replicas**: 1
- **Resources**: 256Mi RAM, 100m CPU
- **Storage**: emptyDir (ephemeral)

### Backup PVC
- **Size**: 20Gi
- **Access**: ReadWriteOnce
- **Class**: standard-rwo

---

## Cost Estimates (us-central1)

| Component | Configuration | Monthly Cost |
|-----------|--------------|--------------|
| Session Manager | 2 pods, e2-medium | ~$25 |
| User Pods (active) | 10 users, 50% uptime | ~$60 |
| Storage | 10 users × 5Gi + 20Gi backup | ~$15 |
| LoadBalancer | 1 external IP | ~$20 |
| **Total** | | **~$120/month** |

**Cost savings:**
- Auto-scaling to 0 saves ~70% on idle pods
- Spot instances (if enabled) save additional 70%

---

## Security Features

✅ **Implemented:**
- API key authentication on all endpoints
- Rate limiting (100 req/min)
- RBAC with minimal permissions
- SSL/TLS via LetsEncrypt
- Workload Identity (no service account keys)
- Per-user pod isolation
- Secrets for credentials

⚠️ **Recommended Hardening:**
- Enable Network Policies (pod-to-pod isolation)
- Add Redis password authentication
- Implement Pod Security Standards
- Add Resource Quotas on namespace
- Enable Admission Controllers

---

## Monitoring & Logs

### Check Session Manager Logs
```bash
kubectl logs -n fresh-system deployment/session-manager -f
```

### Check User Pod Logs
```bash
kubectl logs -n default pod/user-{uuid}-xxxxx -f
```

### Check Redis Logs
```bash
kubectl logs -n fresh-system statefulset/redis -f
```

### Check KEDA Scaling Events
```bash
kubectl get scaledobject -n default
kubectl describe scaledobject user-{uuid}-scaler -n default
```

---

## Backup & Recovery

### Backup Location
Backups are stored in **backup-pvc** (50Gi) in the **default** namespace at `/backup/`

Backup filename format: `app-{uuid}-{timestamp}.zip`

Example: `app-0fa6debc-20251120-130829.zip`

### List All Backups
```bash
# Create temporary viewer pod
kubectl run backup-viewer --image=alpine:latest --restart=Never -n default \
  --overrides='{"spec":{"containers":[{"name":"viewer","image":"alpine:latest","command":["sleep","3600"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"backup-pvc"}}]}}'

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/backup-viewer -n default --timeout=30s

# List all backups
kubectl exec -n default backup-viewer -- ls -lh /backup/

# Clean up viewer pod
kubectl delete pod backup-viewer -n default
```

### Restore from Backup
```bash
# Create viewer pod (if not already running)
kubectl run backup-viewer --image=alpine:latest --restart=Never -n default \
  --overrides='{"spec":{"containers":[{"name":"viewer","image":"alpine:latest","command":["sleep","3600"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"backup-pvc"}}]}}'

# Copy backup from PVC to local
kubectl cp default/backup-viewer:/backup/app-{uuid}-{timestamp}.zip ./backup.zip

# Extract
unzip backup.zip

# Copy to new user pod
kubectl cp ./app default/user-{new-uuid}-xxxxx:/app/

# Clean up
kubectl delete pod backup-viewer -n default
```

---

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod user-{uuid}-xxxxx -n default
kubectl logs user-{uuid}-xxxxx -n default
```

### Session Manager errors
```bash
kubectl logs -n fresh-system deployment/session-manager --tail=100
```

### Redis connection issues
```bash
kubectl exec -n fresh-system redis-0 -- redis-cli ping
```

### KEDA not scaling
```bash
kubectl logs -n keda deployment/keda-operator
kubectl get scaledobject -n default
```

---

## Production Checklist

- [ ] Change API key from default
- [ ] Update DNS to point to LoadBalancer IP
- [ ] Enable Redis password authentication
- [ ] Implement Network Policies
- [ ] Set up monitoring alerts
- [ ] Configure backup retention policy
- [ ] Enable Pod Security Standards
- [ ] Add Resource Quotas
- [ ] Test disaster recovery
- [ ] Document runbook for on-call

---

## Support Contacts

**Infrastructure**: GCP Project `hyperbola-476507`  
**Cluster**: GKE cluster in `us-central1`  
**Namespace**: `fresh-system` (control plane), `default` (user pods)  
**Repository**: `ai-gcp-infra`

---

## Quick Commands Reference

```bash
# Get LoadBalancer IP
kubectl get svc session-manager-lb -n fresh-system

# Scale Session Manager
kubectl scale deployment session-manager -n fresh-system --replicas=3

# Restart Session Manager
kubectl rollout restart deployment session-manager -n fresh-system

# List all user sessions
kubectl get pods -n default -l app

# Delete stuck session
kubectl delete deployment,service,ingress,pvc,scaledobject -n default -l session-uuid={uuid}

# Check cluster health
kubectl get nodes
kubectl top nodes
kubectl top pods -n fresh-system
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-20  
**System Version**: 3.2.0
