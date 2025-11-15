# Client API Guide - v3.0.0

## What Changed

✅ **Pod starts immediately on create** (no message needed)  
✅ **Faster startup** - Increased resources for <45 second target  
✅ **Scale API** - Scale resources up/down  
✅ **Fixed sleep/wake** - Actually scales replicas  
⏳ **PVC backup on delete** - Coming next  

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

### 7. Delete Session
```bash
DELETE /session/{uuid}

Response:
{
  "uuid": "abc12345",
  "status": "terminated"
}
```

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

## Next Steps

1. **Deploy v3.0.0** - Build and push new image
2. **Test all APIs** - Use commands above
3. **Add PVC backup** - Zip data before delete
4. **Optimize startup** - Reduce to <45 seconds

---

## Deploy Commands

```bash
# Build and push v3.0.0
cd /Users/maripeddisupraj/Desktop/ai-gcp-infra/session-manager
docker buildx build --platform linux/amd64 \
  -t us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/session-manager:v3.0.0 \
  -t us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/session-manager:latest \
  --push .

# Restart deployment
kubectl rollout restart deployment/session-manager
kubectl rollout status deployment/session-manager
```
