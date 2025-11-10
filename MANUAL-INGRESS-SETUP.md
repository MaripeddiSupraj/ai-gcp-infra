# Manual Ingress Setup Instructions

## ⚠️ IMPORTANT: Client DNS is pointing to WRONG IP!

Client configured: `*.preview.hyperbola.in → 34.46.174.78`

**Problem:** `34.46.174.78` is the session-manager service, NOT the Ingress controller.

**Solution:** Install Ingress, get NEW IP, tell client to update DNS.

---

## Step 1: Install Nginx Ingress Controller

Run these commands in your terminal (with gcloud access):

```bash
# Get GKE credentials
gcloud container clusters get-credentials primary-cluster-v2 \
  --region us-central1 \
  --project hyperbola-476507

# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install Nginx Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Wait for LoadBalancer IP (takes 2-3 minutes)
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -w
```

**Wait until you see EXTERNAL-IP** (not `<pending>`):
```
NAME                                          TYPE           EXTERNAL-IP
nginx-ingress-ingress-nginx-controller        LoadBalancer   35.x.x.x
```

**Copy that EXTERNAL-IP!**

---

## Step 2: Install Cert-Manager (SSL)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for it to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s

# Create ClusterIssuer for Let's Encrypt
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@hyperbola.in
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

---

## Step 3: Tell Client to Update DNS

**Send this message to client:**

> Hi, please UPDATE the DNS record in GoDaddy:
> 
> **Current (WRONG):**
> ```
> Type: A
> Host: *.preview
> Points to: 34.46.174.78
> ```
> 
> **Change to (CORRECT):**
> ```
> Type: A
> Host: *.preview
> Points to: <NEW_INGRESS_IP>
> ```
> 
> Replace `<NEW_INGRESS_IP>` with the IP from Step 1.
> 
> **Steps in GoDaddy:**
> 1. Go to: https://dcc.godaddy.com/manage/hyperbola.in
> 2. Find the existing `*.preview` A record
> 3. Click "Edit" (pencil icon)
> 4. Change "Points to" from `34.46.174.78` to `<NEW_INGRESS_IP>`
> 5. Click "Save"
> 6. Wait 5-10 minutes for DNS to update

---

## Step 4: Wait for DNS Propagation

After client updates DNS, wait 5-10 minutes, then test:

```bash
# Test DNS resolution
nslookup vs-code-test.preview.hyperbola.in

# Should return the NEW Ingress IP, not 34.46.174.78
```

Or use online tool: https://dnschecker.org

---

## Step 5: Test Session Creation

```bash
# Create a test session
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}'

# Response will include:
# "workspace_url": "https://vs-code-abc123.preview.hyperbola.in"

# Test accessing the workspace URL (after DNS propagates)
curl https://vs-code-abc123.preview.hyperbola.in
```

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

---

## Troubleshooting

### Ingress IP not assigned
```bash
# Check service status
kubectl get svc -n ingress-nginx

# Check events
kubectl get events -n ingress-nginx
```

### DNS not updating
```bash
# Check current DNS
dig vs-code-test.preview.hyperbola.in

# If still showing old IP, wait longer or check GoDaddy
```

### SSL certificate not issued
```bash
# Check certificate status
kubectl get certificate

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

---

## Summary

1. ✅ Install Nginx Ingress → Get NEW IP
2. ✅ Install Cert-Manager → Auto SSL
3. ✅ Client updates DNS: `*.preview.hyperbola.in` → NEW IP
4. ✅ Wait 5-10 minutes
5. ✅ Test and verify

**Current Status:**
- Session Manager: `34.46.174.78` (keep this)
- Ingress Controller: `<NEW_IP>` (need to install)
- DNS should point to: Ingress IP (not session-manager IP)
