#!/bin/bash
# Copy and paste this entire script into your terminal

set -e

echo "🚀 Starting Ingress Installation..."
echo ""

# Navigate to repo
cd /Users/maripeddisupraj/Desktop/ai-gcp-infra

# Get GKE credentials
echo "📡 Getting GKE credentials..."
gcloud container clusters get-credentials primary-cluster-v2 --region us-central1 --project hyperbola-476507

# Apply Nginx Ingress
echo "📦 Installing Nginx Ingress Controller..."
kubectl apply -f k8s-manifests/nginx-ingress.yaml

# Wait for pods
echo "⏳ Waiting for Ingress pods to be ready (2-3 minutes)..."
kubectl wait --for=condition=ready pod -l app=nginx-ingress -n ingress-nginx --timeout=300s

echo ""
echo "✅ Ingress pods are ready!"
echo ""

# Wait for LoadBalancer IP
echo "⏳ Waiting for LoadBalancer IP..."
sleep 30

INGRESS_IP=""
for i in {1..60}; do
  INGRESS_IP=$(kubectl get svc nginx-ingress -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  
  if [ -n "$INGRESS_IP" ]; then
    break
  fi
  
  if [ $((i % 10)) -eq 0 ]; then
    echo "Still waiting for IP... ($i/60 seconds)"
  fi
  sleep 1
done

if [ -z "$INGRESS_IP" ]; then
  echo "❌ LoadBalancer IP not assigned yet"
  echo "Check manually: kubectl get svc nginx-ingress -n ingress-nginx"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ INGRESS LOADBALANCER IP: $INGRESS_IP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Install Cert-Manager
echo "🔐 Installing Cert-Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

echo "⏳ Waiting for Cert-Manager (60 seconds)..."
sleep 60

# Apply ClusterIssuer
echo "📜 Creating Let's Encrypt ClusterIssuer..."
kubectl apply -f k8s-manifests/letsencrypt-issuer.yaml

echo ""
echo "✅ Installation Complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 SEND THIS MESSAGE TO CLIENT:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Hi, please update your DNS record in GoDaddy:"
echo ""
echo "1. Go to: https://dcc.godaddy.com/manage/hyperbola.in"
echo "2. Click on DNS tab"
echo "3. Find the A record: *.preview"
echo "4. Click Edit (pencil icon)"
echo "5. Change 'Points to' from: 34.46.174.78"
echo "6. Change 'Points to' to: $INGRESS_IP"
echo "7. Click Save"
echo "8. Wait 5-10 minutes for DNS to propagate"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Verification commands:"
echo "kubectl get pods -n ingress-nginx"
echo "kubectl get pods -n cert-manager"
echo "kubectl get clusterissuer"
echo ""
