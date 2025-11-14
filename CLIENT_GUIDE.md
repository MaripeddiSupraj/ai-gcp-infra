# 🚀 Session-Based AI Platform - Client Guide

## System Overview

Your platform creates isolated VS Code environments for each user. Each user gets:
- Unique UUID
- Dedicated pod (container)
- Personal workspace URL: `https://vs-code-{uuid}.preview.hyperbola.in`

---

## API Endpoints

**Base URL:** `http://34.46.174.78`  
**API Key:** `your-secure-api-key-change-in-production`  
**Header:** `X-API-Key: your-secure-api-key-change-in-production`

### 1. Create Session
```bash
POST /session/create
Body: {"user_id": "user@example.com"}

Response:
{
  "uuid": "abc12345",
  "user_id": "user@example.com",
  "workspace_url": "https://vs-code-abc12345.preview.hyperbola.in",
  "status": "created"
}
```

### 2. Send Message (Wakes Pod)
```bash
POST /session/{uuid}/chat
Body: {"message": "Hello!"}

Response:
{
  "uuid": "abc12345",
  "status": "queued",
  "message": "Pod is waking up, message queued"
}
```

### 3. Check Status
```bash
GET /session/{uuid}/status

Response:
{
  "uuid": "abc12345",
  "replicas": 1,  # 0 = sleeping, 1 = running
  "queue_length": 0
}
```

### 4. Delete Session
```bash
DELETE /session/{uuid}

Response:
{
  "uuid": "abc12345",
  "status": "terminated"
}
```

---

## How It Works

1. **Create Session** → System creates pod (starts sleeping)
2. **Send Message** → Pod wakes up (takes 15-20 seconds)
3. **User Works** → Pod stays running
4. **Delete Session** → Pod and all resources removed

**Important:** Pods stay running until you delete the session. No automatic shutdown.

---

## Testing

```bash
# Complete test
UUID=$(curl -s -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}' | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4)

echo "Session: $UUID"
echo "Workspace: https://vs-code-$UUID.preview.hyperbola.in"

# Wake pod
curl -X POST http://34.46.174.78/session/$UUID/chat \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"message": "test"}'

# Wait 30 seconds
sleep 30

# Check status (should show replicas: 1)
curl http://34.46.174.78/session/$UUID/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"

# Open in browser
# https://vs-code-$UUID.preview.hyperbola.in
```

---

## Timings

| Action | Time |
|--------|------|
| Create session | < 1 second |
| Pod wakes up | 15-20 seconds |
| VS Code loads | 10-15 seconds |
| **Total first access** | **30-45 seconds** |

---

## Integration Example

```javascript
const API_BASE = 'http://34.46.174.78';
const API_KEY = 'your-secure-api-key-change-in-production';

// Create session
const response = await fetch(`${API_BASE}/session/create`, {
  method: 'POST',
  headers: {
    'X-API-Key': API_KEY,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ user_id: 'user@example.com' })
});

const session = await response.json();
console.log('Workspace:', session.workspace_url);

// Send message to wake pod
await fetch(`${API_BASE}/session/${session.uuid}/chat`, {
  method: 'POST',
  headers: {
    'X-API-Key': API_KEY,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ message: 'Hello!' })
});

// Wait 30 seconds, then open workspace
setTimeout(() => {
  window.open(session.workspace_url, '_blank');
}, 30000);
```

---

## Troubleshooting

### Browser loads slowly
- **Normal:** 30-45 seconds for first access
- **Check pod status:** Should show `"replicas": 1`
- **Wait:** VS Code needs 10-15 seconds to initialize

### Pod not starting
```bash
# Send message again
curl -X POST http://34.46.174.78/session/$UUID/chat \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"message": "wake up"}'
```

---

## System Info

- **Version:** 2.9.0
- **Platform:** Google Kubernetes Engine
- **Domain:** *.preview.hyperbola.in
- **SSL:** Automatic (Let's Encrypt)
- **Image:** Ubuntu 24.04 with VS Code Server

---

## Support

**Health Check:**
```bash
curl http://34.46.174.78/health
```

**GitHub Actions:** https://github.com/MaripeddiSupraj/ai-gcp-infra/actions

**Questions?** Check logs:
```bash
kubectl logs deployment/session-manager --tail=50
```
