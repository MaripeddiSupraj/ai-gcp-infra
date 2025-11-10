#!/bin/bash
set -e

echo "🚀 Deploying Nginx Ingress Controller..."
echo ""

# Apply Nginx Ingress
kubectl apply -f k8s-manifests/nginx-ingress.yaml

echo "⏳ Waiting for Ingress pods to be ready..."
kubectl wait --for=condition=ready pod -l app=nginx-ingress -n ingress-nginx --timeout=300s

echo ""
echo "⏳ Waiting for LoadBalancer IP (2-3 minutes)..."
echo ""

# Wait for LoadBalancer IP
for i in {1..60}; do
  INGRESS_IP=$(kubectl get svc nginx-ingress -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  
  if [ -n "$INGRESS_IP" ]; then
    break
  fi
  
  if [ $((i % 6)) -eq 0 ]; then
    echo "Still waiting... ($i/60 seconds)"
  fi
  sleep 1
done

if [ -z "$INGRESS_IP" ]; then
  echo "❌ LoadBalancer IP not assigned yet. Check status:"
  echo "kubectl get svc -n ingress-nginx nginx-ingress"
  exit 1
fi

echo ""
echo "✅ Nginx Ingress deployed successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 INGRESS LOADBALANCER IP: $INGRESS_IP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Install cert-manager
echo "🔐 Installing Cert-Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

echo "⏳ Waiting for cert-manager to be ready..."
sleep 30
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s 2>/dev/null || echo "Cert-manager pods starting..."

echo ""
echo "📜 Creating Let's Encrypt ClusterIssuer..."
sleep 10
kubectl apply -f k8s-manifests/letsencrypt-issuer.yaml

echo ""
echo "✅ Setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 MESSAGE FOR CLIENT:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Please UPDATE your DNS record in GoDaddy:"
echo ""
echo "1. Go to: https://dcc.godaddy.com/manage/hyperbola.in"
echo "2. Find the A record: *.preview"
echo "3. Click Edit"
echo "4. Change 'Points to' from: 34.46.174.78"
echo "5. Change 'Points to' to: $INGRESS_IP"
echo "6. Click Save"
echo "7. Wait 5-10 minutes for DNS to propagate"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "After DNS updates, test with:"
echo "curl -X POST http://34.46.174.78/session/create \\"
echo "  -H 'X-API-Key: your-secure-api-key-change-in-production' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"user_id\": \"test@example.com\"}'"
echo ""
