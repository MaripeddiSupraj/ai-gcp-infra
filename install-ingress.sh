#!/bin/bash
set -e

echo "🚀 Installing Nginx Ingress Controller on GKE..."
echo ""

# Get GKE credentials
gcloud container clusters get-credentials primary-cluster-v2 --region us-central1 --project hyperbola-476507

# Add Helm repo
echo "📦 Adding Helm repository..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install Nginx Ingress
echo "⚙️  Installing Nginx Ingress..."
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

echo ""
echo "⏳ Waiting for LoadBalancer IP (this takes 2-3 minutes)..."
echo ""

sleep 30

# Wait for LoadBalancer IP
INGRESS_IP=""
for i in {1..30}; do
  INGRESS_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  
  if [ -n "$INGRESS_IP" ]; then
    break
  fi
  
  echo "Still waiting... ($i/30)"
  sleep 10
done

if [ -z "$INGRESS_IP" ]; then
  echo "❌ Failed to get LoadBalancer IP. Check manually:"
  echo "kubectl get svc -n ingress-nginx"
  exit 1
fi

echo ""
echo "✅ Nginx Ingress installed successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 INGRESS LOADBALANCER IP: $INGRESS_IP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  IMPORTANT: Tell client to UPDATE DNS record in GoDaddy:"
echo ""
echo "   OLD: *.preview.hyperbola.in → 34.46.174.78"
echo "   NEW: *.preview.hyperbola.in → $INGRESS_IP"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Install cert-manager
echo "🔐 Installing Cert-Manager for SSL..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

echo "⏳ Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s 2>/dev/null || true

# Create ClusterIssuer
echo "📜 Creating Let's Encrypt ClusterIssuer..."
cat <<EOF | kubectl apply -f -
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

echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Client updates DNS: *.preview.hyperbola.in → $INGRESS_IP"
echo "  2. Wait 5-10 minutes for DNS propagation"
echo "  3. Test: curl https://vs-code-test.preview.hyperbola.in"
echo ""
