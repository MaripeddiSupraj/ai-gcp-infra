#!/bin/bash
set -e

echo "🚀 Deploying CLIENT Session Manager (Fresh Setup)"

# Build and push client session manager
echo "📦 Building client session manager..."
cd client-session-manager
docker build -t us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/client-session-manager:latest .
docker push us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/client-session-manager:latest

cd ..

# Deploy Redis
echo "📊 Deploying client Redis..."
kubectl apply -f k8s-manifests/client-redis.yaml

# Wait for Redis
echo "⏳ Waiting for Redis to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/client-redis

# Deploy session manager
echo "🎯 Deploying client session manager..."
kubectl apply -f k8s-manifests/client-session-manager.yaml

# Wait for session manager
echo "⏳ Waiting for session manager to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/client-session-manager

echo "✅ CLIENT Session Manager deployed successfully!"
echo "🌐 API URL: https://client-api.preview.hyperbola.in"
echo "🔑 API Key: client-api-key-2024"
echo ""
echo "📋 Test commands:"
echo "curl -X POST https://client-api.preview.hyperbola.in/session/create \\"
echo "  -H 'X-API-Key: client-api-key-2024' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"user_id\": \"test-user\"}'"