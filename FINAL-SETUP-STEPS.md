# Final Setup Steps - VS Code Access via Ingress

## Current Status
- ✅ Session Manager API: Running at `34.46.174.78`
- ✅ Code updated: Uses `preview.hyperbola.in` domain
- ✅ Client DNS: Configured `*.preview.hyperbola.in → 34.46.174.78` (WRONG IP)
- ❌ Ingress: Not installed yet (NEED TO INSTALL)

## Problem
Client pointed DNS to session-manager IP (`34.46.174.78`) instead of Ingress IP.

## Solution (3 Steps)

### Step 1: Install Ingress (You Do This)

Run these commands:

```bash
# Apply Nginx Ingress
kubectl apply -f k8s-manifests/nginx-ingress.yaml

# Wait for it to be ready
kubectl wait --for=condition=ready pod -l app=nginx-ingress -n ingress-nginx --timeout=300s

# Get the LoadBalancer IP (wait if <pending>)
kubectl get svc nginx-ingress -n ingress-nginx

# Install Cert-Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait 60 seconds
sleep 60

# Apply Let's Encrypt Issuer
kubectl apply -f k8s-manifests/letsencrypt-issuer.yaml
```

**Get the Ingress IP:**
```bash
kubectl get svc nginx-ingress -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Example output: `35.123.45.67`

---

### Step 2: Tell Client to Update DNS

Send this message to client:

> **Hi, please update the DNS record in GoDaddy:**
> 
> The current DNS is pointing to the wrong IP. Please change it:
> 
> **Current (Wrong):**
> - Host: `*.preview`
> - Points to: `34.46.174.78`
> 
> **Update to (Correct):**
> - Host: `*.preview`
> - Points to: `<INGRESS_IP_FROM_STEP_1>`
> 
> **Steps:**
> 1. Go to: https://dcc.godaddy.com/manage/hyperbola.in
> 2. Click on DNS
> 3. Find the A record with Host `*.preview`
> 4. Click the pencil icon (Edit)
> 5. Change "Points to" from `34.46.174.78` to `<NEW_IP>`
> 6. Click "Save"
> 7. Wait 5-10 minutes for DNS to propagate
> 
> Let me know when it's done!

---

### Step 3: Test Everything

After client confirms DNS is updated, wait 5-10 minutes, then test:

```bash
# 1. Test DNS resolution
nslookup vs-code-test.preview.hyperbola.in
# Should return the NEW Ingress IP

# 2. Create a test session
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}'

# Response will include:
# {
#   "uuid": "abc123",
#   "workspace_url": "https://vs-code-abc123.preview.hyperbola.in",
#   ...
# }

# 3. Test accessing the workspace URL
curl https://vs-code-abc123.preview.hyperbola.in

# 4. Check Ingress was created
kubectl get ingress user-abc123

# 5. Check SSL certificate
kubectl get certificate tls-abc123
```

---

## Architecture After Setup

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└─────────────────────────────────────────────────────────────┘
                    │                    │
                    │                    │
         API Calls  │                    │  VS Code Access
         (34.46.174.78)                  │  (NEW_INGRESS_IP)
                    │                    │
                    ▼                    ▼
         ┌──────────────────┐  ┌──────────────────┐
         │ Session Manager  │  │ Nginx Ingress    │
         │   (API Server)   │  │   Controller     │
         └──────────────────┘  └──────────────────┘
                    │                    │
                    │                    │
                    └────────┬───────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │   User Pods      │
                    │ (VS Code Envs)   │
                    └──────────────────┘
```

**DNS Configuration:**
- `*.preview.hyperbola.in` → `<INGRESS_IP>` (for VS Code access)
- API calls still use: `34.46.174.78` (session-manager)

---

## Verification Checklist

- [ ] Nginx Ingress installed
- [ ] LoadBalancer IP obtained
- [ ] Cert-Manager installed
- [ ] ClusterIssuer created
- [ ] Client updated DNS record
- [ ] DNS propagation complete (5-10 min)
- [ ] Test session creation works
- [ ] Workspace URL accessible
- [ ] SSL certificate auto-issued

---

## Troubleshooting

### Ingress IP shows <pending>
```bash
# Check events
kubectl get events -n ingress-nginx

# Check service
kubectl describe svc nginx-ingress -n ingress-nginx
```

### DNS not resolving to new IP
```bash
# Check DNS
dig vs-code-test.preview.hyperbola.in

# Use online checker
# https://dnschecker.org
```

### SSL certificate not issued
```bash
# Check certificate status
kubectl describe certificate tls-abc123

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

### Ingress not routing to pod
```bash
# Check Ingress
kubectl get ingress user-abc123 -o yaml

# Check Ingress controller logs
kubectl logs -n ingress-nginx -l app=nginx-ingress
```

---

## Summary

1. **You:** Install Ingress → Get IP
2. **Client:** Update DNS to new IP
3. **Wait:** 5-10 minutes for DNS
4. **Test:** Create session and access workspace URL
5. **Done:** Users can access `https://vs-code-{uuid}.preview.hyperbola.in`

**Start with Step 1 above!** 🚀
