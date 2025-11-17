#!/bin/bash

echo "🔄 Deploying persistent storage fix..."

# Apply persistent volume claims first
echo "📦 Creating persistent volume claims..."
kubectl apply -f k8s-manifests/persistent-storage.yaml

# Wait for PVCs to be bound
echo "⏳ Waiting for PVCs to be bound..."
kubectl wait --for=condition=Bound pvc/mongodb-pvc --timeout=300s
kubectl wait --for=condition=Bound pvc/workspace-pvc --timeout=300s
kubectl wait --for=condition=Bound pvc/home-pvc --timeout=300s

# Apply updated deployment
echo "🚀 Updating deployment with persistent storage..."
kubectl apply -f k8s-manifests/ai-app-deployment.yaml

# Wait for rollout to complete
echo "⏳ Waiting for deployment rollout..."
kubectl rollout status deployment/ai-environment --timeout=600s

echo "✅ Persistent storage deployment complete!"
echo ""
echo "📊 Storage status:"
kubectl get pvc
echo ""
echo "🔍 Pod status:"
kubectl get pods -l app=ai-environment