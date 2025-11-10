#!/bin/bash
# Quick Ingress Setup Script

echo "🚀 Installing Nginx Ingress Controller..."

# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install Nginx Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

echo "⏳ Waiting for LoadBalancer IP (this may take 2-3 minutes)..."
sleep 30

# Get LoadBalancer IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

while [ -z "$INGRESS_IP" ]; do
  echo "Still waiting for IP..."
  sleep 10
  INGRESS_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
done

echo ""
echo "✅ Nginx Ingress installed successfully!"
echo ""
echo "📍 LoadBalancer IP: $INGRESS_IP"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 SEND THIS TO CLIENT (GoDaddy DNS Setup):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Please add this DNS record in GoDaddy:"
echo ""
echo "  1. Go to: https://dcc.godaddy.com/manage/dns"
echo "  2. Select your domain"
echo "  3. Click 'Add' button"
echo "  4. Enter these details:"
echo ""
echo "     Type: A"
echo "     Host: *.ai  (or *.workspace, whatever subdomain you chose)"
echo "     Points to: $INGRESS_IP"
echo "     TTL: 600 seconds"
echo ""
echo "  5. Click 'Save'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔧 Installing Cert-Manager for SSL..."

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

echo "⏳ Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
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
echo "  1. Wait for client to add DNS record in GoDaddy"
echo "  2. Update session-manager/app.py with client's subdomain"
echo "  3. Deploy and test"
echo ""
