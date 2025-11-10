# Ingress Setup for VS Code Access

## Overview

Each user session gets a unique subdomain:
- User creates session → UUID: `abc123`
- Access via: `https://vs-code-abc123.yourdomain.com`
- Routes to → User's pod internally

## Prerequisites

1. **Domain name** (e.g., `yourdomain.com`)
2. **Nginx Ingress Controller** installed in GKE
3. **Cert-Manager** for SSL certificates
4. **Wildcard DNS** configured

---

## Step 1: Install Nginx Ingress Controller

```bash
# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install Nginx Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Get LoadBalancer IP (this is your main entry point)
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

**Save the EXTERNAL-IP** - you'll use this for DNS.

---

## Step 2: Install Cert-Manager (for SSL)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

---

## Step 3: Configure DNS

### Option A: Using Cloud DNS (GCP)

```bash
# Get Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Create wildcard DNS record
gcloud dns record-sets create "*.yourdomain.com." \
  --zone="your-dns-zone" \
  --type="A" \
  --ttl="300" \
  --rrdatas="$INGRESS_IP"
```

### Option B: Manual DNS Setup

In your DNS provider (Namecheap, GoDaddy, Cloudflare, etc.):

1. Create an **A record**:
   - Host: `*` (wildcard)
   - Points to: `<INGRESS_IP>`
   - TTL: 300

Example:
```
Type: A
Name: *
Value: 34.123.45.67
TTL: 300
```

This allows:
- `vs-code-abc123.yourdomain.com` → Routes to Ingress
- `vs-code-xyz789.yourdomain.com` → Routes to Ingress
- Ingress → Routes to correct pod based on hostname

---

## Step 4: Update session-manager Configuration

Replace `yourdomain.com` in `session-manager/app.py`:

```python
# Line ~280
workspace_url = f"https://vs-code-{session_uuid}.yourdomain.com"
```

Change to your actual domain:
```python
workspace_url = f"https://vs-code-{session_uuid}.mycompany.com"
```

---

## Step 5: Deploy and Test

```bash
# Commit changes
git add session-manager/app.py
git commit -m "feat: Configure Ingress with real domain"
git push origin main

# Wait for deployment (auto-deploys via GitHub Actions)
# Check deployment status
kubectl get pods -l app=session-manager

# Test session creation
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}'

# Response will include:
# "workspace_url": "https://vs-code-abc123.mycompany.com"
```

---

## Verification

1. **Check Ingress created:**
   ```bash
   kubectl get ingress
   ```

2. **Check certificate issued:**
   ```bash
   kubectl get certificate
   ```

3. **Test access:**
   ```bash
   curl https://vs-code-abc123.mycompany.com
   ```

---

## Cost Estimate

| Resource | Cost |
|----------|------|
| Nginx Ingress LoadBalancer | ~$20/month |
| Cert-Manager (free) | $0 |
| DNS (Cloud DNS) | ~$0.40/month |
| **Total** | **~$20/month** |

---

## Troubleshooting

### Ingress not working
```bash
# Check Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Check if Ingress was created
kubectl get ingress user-abc123 -o yaml
```

### SSL certificate not issued
```bash
# Check certificate status
kubectl describe certificate tls-abc123

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

### DNS not resolving
```bash
# Test DNS resolution
nslookup vs-code-abc123.mycompany.com

# Check if wildcard is configured
dig *.mycompany.com
```

---

## Alternative: Use nip.io (Testing Only)

For testing without a domain:

```python
# In session-manager/app.py
INGRESS_IP = "34.123.45.67"  # Your Ingress IP
workspace_url = f"https://vs-code-{session_uuid}.{INGRESS_IP}.nip.io"
```

This gives you: `https://vs-code-abc123.34.123.45.67.nip.io`

**Note:** nip.io is for testing only, not production.

---

## Summary

✅ **What you need:**
1. Install Nginx Ingress Controller
2. Install Cert-Manager
3. Configure wildcard DNS (*.yourdomain.com)
4. Update domain in session-manager code
5. Deploy

✅ **Result:**
- Each session gets: `https://vs-code-{uuid}.yourdomain.com`
- Automatic SSL certificates
- Routes to correct user pod
- Cost: ~$20/month
