# Client API Guide - v3.1.0

## What's New in v3.1.0

✅ **Persistent Storage** - Each user gets 5Gi PVC at `/workspace`  
✅ **Automatic Backup** - Data zipped before session deletion  
✅ **Backup Storage** - All backups saved to shared 50Gi PVC  
✅ **Pod starts immediately** - No message needed to start  
✅ **Resource scaling** - Scale CPU/RAM up or down  
✅ **Sleep/Wake APIs** - Manual pod control  

---

## API Endpoints

**Base:** `http://34.46.174.78`  
**API Key:** `your-secure-api-key-change-in-production`  
**Header:** `X-API-Key: your-secure-api-key-change-in-production`

### 1. Create Session (Pod Starts Immediately)
```bash
POST /session/create
Body: {"user_id": "user@example.com"}

Response:
{
  "uuid": "abc12345",
  "workspace_url": "https://vs-code-abc12345.preview.hyperbola.in",
  "status": "created"
}
```
**Pod starts immediately with 1Gi RAM, 1 CPU**

### 2. Send Message
```bash
POST /session/{uuid}/chat
Body: {"message": "Hello!"}
```

### 3. Check Status
```bash
GET /session/{uuid}/status

Response:
{
  "uuid": "abc12345",
  "replicas": 1,  # 0=sleeping, 1=running
  "queue_length": 0
}
```

### 4. Sleep Pod (Scale to 0)
```bash
POST /session/{uuid}/sleep

Response:
{
  "uuid": "abc12345",
  "action": "sleep",
  "status": "sleeping"
}
```

### 5. Wake Pod (Scale to 1)
```bash
POST /session/{uuid}/wake

Response:
{
  "uuid": "abc12345",
  "action": "wake",
  "status": "waking"
}
```

### 6. Scale Resources
```bash
POST /session/{uuid}/scale
Body: {"scale": "up"}   # or "down"

Response:
{
  "uuid": "abc12345",
  "action": "scale_up",
  "status": "success"
}
```

**Scale Up:** 2Gi RAM, 2 CPU  
**Scale Down:** 1Gi RAM, 1 CPU  

### 7. Delete Session (with Backup)
```bash
DELETE /session/{uuid}

Response:
{
  "uuid": "abc12345",
  "status": "terminated",
  "message": "Session and all resources deleted"
}
```
**Note:** Backup job runs automatically before deletion

---

## Test Commands

```bash
# 1. Create session (pod starts immediately)
UUID=$(curl -s -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}' | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4)

echo "Session: $UUID"
echo "Workspace: https://vs-code-$UUID.preview.hyperbola.in"

# 2. Wait 45 seconds for pod to start
sleep 45

# 3. Check status (should show replicas: 1)
curl http://34.46.174.78/session/$UUID/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"

# 4. Test sleep
curl -X POST http://34.46.174.78/session/$UUID/sleep \
  -H "X-API-Key: your-secure-api-key-change-in-production"

sleep 10

# 5. Check status (should show replicas: 0)
curl http://34.46.174.78/session/$UUID/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"

# 6. Test wake
curl -X POST http://34.46.174.78/session/$UUID/wake \
  -H "X-API-Key: your-secure-api-key-change-in-production"

sleep 30

# 7. Check status (should show replicas: 1)
curl http://34.46.174.78/session/$UUID/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"

# 8. Test scale up
curl -X POST http://34.46.174.78/session/$UUID/scale \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"scale": "up"}'

# 9. Test scale down
curl -X POST http://34.46.174.78/session/$UUID/scale \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"scale": "down"}'

# 10. Delete session
curl -X DELETE http://34.46.174.78/session/$UUID \
  -H "X-API-Key: your-secure-api-key-change-in-production"
```

---

## Timings

| Action | Time | Notes |
|--------|------|-------|
| Create session | < 1s | Pod starts immediately |
| Pod ready | 30-45s | Target: <45 seconds |
| Sleep | 5-10s | Scales to 0 |
| Wake | 30-45s | Scales to 1 |
| Scale up/down | 10-20s | Rolling update |

---

## Complete User Flow (Step-by-Step)

### Step 1: User Login → Create Session

**What Happens:**
1. Your backend receives user login
2. Call session API to create dedicated workspace
3. System creates:
   - Kubernetes Deployment (user-{uuid})
   - PersistentVolumeClaim (pvc-{uuid}) - 5Gi storage
   - Service (user-{uuid})
   - Ingress with SSL (vs-code-{uuid}.preview.hyperbola.in)
4. Pod starts immediately with 1Gi RAM, 1 CPU
5. User data persists in `/workspace` directory

**Command:**
```bash
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "john@example.com"}'
```

**Response:**
```json
{
  "uuid": "1823b3a8",
  "user_id": "john@example.com",
  "status": "created",
  "created_at": "2025-11-15T03:51:36.653291",
  "workspace_url": "https://vs-code-1823b3a8.preview.hyperbola.in"
}
```

**Timeline:**
- API response: < 1 second
- Pod starting: 30-45 seconds
- VS Code accessible: ~45 seconds total

---

### Step 2: User Works in VS Code

**What Happens:**
1. User opens `workspace_url` in browser
2. VS Code Server loads from pod
3. All files saved to `/workspace` (persistent storage)
4. Pod stays running (replicas=1)
5. Data survives pod restarts

**Check Pod Status:**
```bash
curl http://34.46.174.78/session/1823b3a8/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"
```

**Response:**
```json
{
  "uuid": "1823b3a8",
  "session": {
    "user_id": "john@example.com",
    "status": "created",
    "created_at": "2025-11-15T03:51:36.653291",
    "last_activity": "2025-11-15T04:15:22.123456"
  },
  "replicas": 1,
  "queue_length": 0
}
```

---

### Step 3: User Needs More Resources

**What Happens:**
1. User running heavy workload (compilation, AI model)
2. Call scale API to increase resources
3. Pod updates to 2Gi RAM, 2 CPU
4. Rolling update (10-20 seconds)

**Command:**
```bash
curl -X POST http://34.46.174.78/session/1823b3a8/scale \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"scale": "up"}'
```

**Response:**
```json
{
  "uuid": "1823b3a8",
  "action": "scale_up",
  "status": "success",
  "message": "Pod scaled up"
}
```

---

### Step 4: User Inactive → Sleep Pod

**What Happens:**
1. User inactive for X minutes (your logic)
2. Call sleep API to save costs
3. Pod scales to 0 replicas
4. PVC data remains intact
5. No charges for pod (only storage)

**Command:**
```bash
curl -X POST http://34.46.174.78/session/1823b3a8/sleep \
  -H "X-API-Key: your-secure-api-key-change-in-production"
```

**Response:**
```json
{
  "uuid": "1823b3a8",
  "action": "sleep",
  "status": "sleeping",
  "message": "Pod queued for sleep"
}
```

**Verify:**
```bash
curl http://34.46.174.78/session/1823b3a8/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"
# replicas: 0
```

---

### Step 5: User Returns → Wake Pod

**What Happens:**
1. User clicks "Resume Workspace"
2. Call wake API
3. Pod scales to 1 replica
4. All files still in `/workspace`
5. User continues where they left off

**Command:**
```bash
curl -X POST http://34.46.174.78/session/1823b3a8/wake \
  -H "X-API-Key: your-secure-api-key-change-in-production"
```

**Response:**
```json
{
  "uuid": "1823b3a8",
  "action": "wake",
  "status": "waking"
}
```

**Wait 30-45 seconds, then check:**
```bash
curl http://34.46.174.78/session/1823b3a8/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"
# replicas: 1
```

---

### Step 6: User Logout → Delete Session

**What Happens:**
1. User clicks "Delete Workspace" or logs out permanently
2. Call delete API
3. System creates backup job:
   - Mounts user PVC (read-only)
   - Zips all files in `/workspace`
   - Saves to shared backup PVC: `/backups/workspace-{uuid}-{timestamp}.zip`
4. Waits up to 60 seconds for backup
5. Deletes all resources:
   - Deployment (user-{uuid})
   - Service (user-{uuid})
   - Ingress (user-{uuid})
   - PVC (pvc-{uuid})
   - Redis session data
6. Backup remains in shared storage

**Command:**
```bash
curl -X DELETE http://34.46.174.78/session/1823b3a8 \
  -H "X-API-Key: your-secure-api-key-change-in-production"
```

**Response:**
```json
{
  "uuid": "1823b3a8",
  "status": "terminated",
  "message": "Session and all resources deleted"
}
```

**Verify Backup Created:**
```bash
kubectl get jobs -l session-uuid=1823b3a8
# Shows: backup-1823b3a8

kubectl logs job/backup-1823b3a8
# Shows: Backup completed for 1823b3a8
```

---

## Resource Lifecycle

```
CREATE SESSION
    ↓
[PVC Created] ← 5Gi persistent storage
    ↓
[Pod Starting] ← 1Gi RAM, 1 CPU, replicas=1
    ↓
[User Working] ← Files saved to /workspace
    ↓
[Scale Up?] ← Optional: 2Gi RAM, 2 CPU
    ↓
[Sleep?] ← Optional: replicas=0, PVC remains
    ↓
[Wake?] ← Optional: replicas=1, data intact
    ↓
DELETE SESSION
    ↓
[Backup Job] ← Zip /workspace to backup-pvc
    ↓
[Cleanup] ← Delete deployment, service, ingress, PVC
    ↓
[Backup Stored] ← /backups/workspace-{uuid}-{timestamp}.zip
```

---

## Kubernetes Resources Created

For each user session (e.g., UUID: `1823b3a8`):

```bash
# PersistentVolumeClaim
kubectl get pvc pvc-1823b3a8
# 5Gi storage, mounted at /workspace

# Deployment
kubectl get deployment user-1823b3a8
# 1 replica, Ubuntu 24.04 + VS Code Server

# Service
kubectl get service user-1823b3a8
# ClusterIP, port 80 → 1111

# Ingress
kubectl get ingress user-1823b3a8
# Host: vs-code-1823b3a8.preview.hyperbola.in
# TLS: Let's Encrypt certificate

# Pod
kubectl get pod -l app=user-1823b3a8
# Running VS Code Server
```

---

## Cost Optimization

| State | Resources | Cost/Hour | Use Case |
|-------|-----------|-----------|----------|
| Running | 1Gi RAM, 1 CPU | ~$0.05 | Active user |
| Scaled Up | 2Gi RAM, 2 CPU | ~$0.10 | Heavy workload |
| Sleeping | 0 replicas, 5Gi PVC | ~$0.001 | Inactive user |
| Deleted | Backup only | ~$0.0001 | User logged out |

**Recommendation:**
- Sleep after 15 minutes inactivity
- Delete after 7 days of sleep
- Keep backups for 30 days

---

## Monitoring Commands

```bash
# List all active sessions
curl http://34.46.174.78/sessions \
  -H "X-API-Key: your-secure-api-key-change-in-production"

# Get metrics
curl http://34.46.174.78/metrics

# Health check
curl http://34.46.174.78/health

# View all user pods
kubectl get pods -l uuid

# View all PVCs
kubectl get pvc | grep pvc-

# View backup jobs
kubectl get jobs -l job-type=backup

# View backup files
kubectl exec -it deployment/session-manager -- ls -lh /backups/
```

---

## Integration Example (Node.js)

```javascript
const axios = require('axios');

const API_BASE = 'http://34.46.174.78';
const API_KEY = 'your-secure-api-key-change-in-production';

class WorkspaceManager {
  async createSession(userId) {
    const response = await axios.post(`${API_BASE}/session/create`, 
      { user_id: userId },
      { headers: { 'X-API-Key': API_KEY } }
    );
    return response.data; // { uuid, workspace_url, status }
  }

  async getStatus(uuid) {
    const response = await axios.get(`${API_BASE}/session/${uuid}/status`,
      { headers: { 'X-API-Key': API_KEY } }
    );
    return response.data;
  }

  async sleepSession(uuid) {
    await axios.post(`${API_BASE}/session/${uuid}/sleep`,
      {},
      { headers: { 'X-API-Key': API_KEY } }
    );
  }

  async wakeSession(uuid) {
    await axios.post(`${API_BASE}/session/${uuid}/wake`,
      {},
      { headers: { 'X-API-Key': API_KEY } }
    );
  }

  async deleteSession(uuid) {
    await axios.delete(`${API_BASE}/session/${uuid}`,
      { headers: { 'X-API-Key': API_KEY } }
    );
  }
}

// Usage
const manager = new WorkspaceManager();

// User logs in
const session = await manager.createSession('john@example.com');
console.log('Workspace:', session.workspace_url);

// User inactive for 15 minutes
await manager.sleepSession(session.uuid);

// User returns
await manager.wakeSession(session.uuid);

// User logs out
await manager.deleteSession(session.uuid);
```
