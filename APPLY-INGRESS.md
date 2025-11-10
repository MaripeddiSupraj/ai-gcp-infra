# Quick Ingress Deployment

## Run These Commands

```bash
# 1. Apply Nginx Ingress
kubectl apply -f k8s-manifests/nginx-ingress.yaml

# 2. Wait for pods to be ready (2-3 minutes)
kubectl wait --for=condition=ready pod -l app=nginx-ingress -n ingress-nginx --timeout=300s

# 3. Get the LoadBalancer IP
kubectl get svc nginx-ingress -n ingress-nginx

# Look for EXTERNAL-IP (wait if it shows <pending>)
# Example output:
# NAME            TYPE           EXTERNAL-IP     PORT(S)
# nginx-ingress   LoadBalancer   35.123.45.67    80:30080/TCP,443:30443/TCP

# 4. Install Cert-Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 5. Wait for cert-manager (1-2 minutes)
sleep 60

# 6. Apply Let's Encrypt Issuer
kubectl apply -f k8s-manifests/letsencrypt-issuer.yaml

# 7. Verify everything is running
kubectl get pods -n ingress-nginx
kubectl get pods -n cert-manager
kubectl get clusterissuer
```

## Get the Ingress IP

```bash
kubectl get svc nginx-ingress -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## Tell Client

Once you have the IP (e.g., `35.123.45.67`), send this to client:

> **Please update your DNS record in GoDaddy:**
> 
> 1. Go to: https://dcc.godaddy.com/manage/hyperbola.in
> 2. Find the A record: `*.preview`
> 3. Click "Edit"
> 4. Change "Points to" from `34.46.174.78` to `<NEW_IP>`
> 5. Click "Save"
> 6. Wait 5-10 minutes

## Test After DNS Updates

```bash
# Test DNS
nslookup vs-code-test.preview.hyperbola.in

# Create test session
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}'

# Try accessing the workspace URL from response
curl https://vs-code-<uuid>.preview.hyperbola.in
```

## Done! ✅
