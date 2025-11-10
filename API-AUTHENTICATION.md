# 🔐 API Authentication Guide

## Overview
All Session Manager API endpoints now require API key authentication for security.

## Setup

### 1. Generate Secure API Key
```bash
# Generate a strong random API key
openssl rand -base64 32
```

### 2. Update Secret
Edit `k8s-manifests/api-secret.yaml`:
```yaml
stringData:
  api-key: "YOUR-GENERATED-KEY-HERE"
```

### 3. Apply Secret
```bash
kubectl apply -f k8s-manifests/api-secret.yaml
```

### 4. Wait for Workflow & Restart
```bash
# After GitHub Actions builds new image
kubectl rollout restart deployment/session-manager
kubectl rollout status deployment/session-manager
```

## Usage

### Authentication Methods

**Option 1: X-API-Key Header (Recommended)**
```bash
curl -H "X-API-Key: your-api-key-here" \
  http://34.46.174.78/session/create
```

**Option 2: Authorization Bearer Token**
```bash
curl -H "Authorization: Bearer your-api-key-here" \
  http://34.46.174.78/session/create
```

### Example Requests

#### Create Session
```bash
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user@example.com"}'
```

#### Wake Pod
```bash
curl -X POST http://34.46.174.78/session/{uuid}/wake \
  -H "X-API-Key: your-api-key-here"
```

#### Get Status
```bash
curl http://34.46.174.78/session/{uuid}/status \
  -H "X-API-Key: your-api-key-here"
```

### JavaScript/Frontend Example
```javascript
const API_KEY = 'your-api-key-here';
const BASE_URL = 'http://34.46.174.78';

// Create session
const response = await fetch(`${BASE_URL}/session/create`, {
  method: 'POST',
  headers: {
    'X-API-Key': API_KEY,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({user_id: 'user@example.com'})
});

const {uuid} = await response.json();
```

## Error Responses

### Missing API Key (401)
```json
{
  "error": "API key required",
  "message": "Include X-API-Key header"
}
```

### Invalid API Key (403)
```json
{
  "error": "Invalid API key"
}
```

## Protected Endpoints

All endpoints except `/health` and `/metrics` require authentication:

- ✅ `POST /session/create` - **Requires API Key**
- ✅ `POST /session/{uuid}/wake` - **Requires API Key**
- ✅ `POST /session/{uuid}/sleep` - **Requires API Key**
- ✅ `POST /session/{uuid}/chat` - **Requires API Key**
- ✅ `GET /session/{uuid}/status` - **Requires API Key**
- ✅ `DELETE /session/{uuid}` - **Requires API Key**
- ✅ `GET /sessions` - **Requires API Key**
- ⚪ `GET /health` - Public (no auth)
- ⚪ `GET /metrics` - Public (no auth)

## Security Best Practices

1. **Never commit API keys to Git**
2. **Use environment variables** in production
3. **Rotate keys regularly** (every 90 days)
4. **Use HTTPS** in production (not HTTP)
5. **Store keys securely** (AWS Secrets Manager, etc.)
6. **Different keys per environment** (dev, staging, prod)

## Deployment Steps

1. Generate API key: `openssl rand -base64 32`
2. Update `k8s-manifests/api-secret.yaml`
3. Apply secret: `kubectl apply -f k8s-manifests/api-secret.yaml`
4. Wait for workflow to build new image (~2 min)
5. Restart: `kubectl rollout restart deployment/session-manager`
6. Test with API key
7. Share API key with client securely (not via email/Slack)

## Testing

```bash
# Without API key (should fail)
curl http://34.46.174.78/session/create
# Response: {"error": "API key required"}

# With API key (should work)
curl -H "X-API-Key: your-key" http://34.46.174.78/session/create
# Response: {"uuid": "...", "status": "created"}
```
