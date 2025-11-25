#!/bin/bash
set -e

echo "🔍 SYSTEM INSTALLATION PERSISTENCE TEST"
echo "======================================"

# Create new session
echo "📝 Step 1: Create new session"
RESPONSE=$(curl -s -X POST http://136.119.229.69/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-install-persistence@example.com"}')

SESSION_UUID=$(echo $RESPONSE | jq -r '.uuid')
echo "✅ Session created: $SESSION_UUID"

# Wait for pod
echo "📝 Step 2: Wait for pod to be ready"
sleep 45

# Get pod name
POD_NAME=$(kubectl get pod -n fresh-system -l uuid=${SESSION_UUID} -o jsonpath='{.items[0].metadata.name}')
echo "Pod name: $POD_NAME"

# Check volume mounts
echo "📝 Step 3: Check volume mounts in pod"
kubectl get pod -n fresh-system $POD_NAME -o jsonpath='{.spec.containers[0].volumeMounts}' | jq .

# Test installation persistence paths
echo "📝 Step 4: Test system installation paths"

echo "=== Testing /usr/local (pip installs) ==="
kubectl exec -n fresh-system $POD_NAME -- ls -la /usr/local || echo "❌ /usr/local not mounted"

echo "=== Testing /opt (custom software) ==="
kubectl exec -n fresh-system $POD_NAME -- ls -la /opt || echo "❌ /opt not mounted"

echo "=== Testing /var/lib (apt packages) ==="
kubectl exec -n fresh-system $POD_NAME -- ls -la /var/lib || echo "❌ /var/lib not mounted"

# Install something and test persistence
echo "📝 Step 5: Install software and test persistence"
echo "Installing pip package..."
kubectl exec -n fresh-system $POD_NAME -- pip install requests || echo "pip install failed"

echo "Installing apt package..."
kubectl exec -n fresh-system $POD_NAME -- apt update && apt install -y curl || echo "apt install failed"

echo "Creating custom software in /opt..."
kubectl exec -n fresh-system $POD_NAME -- mkdir -p /opt/myapp && echo "test" > /opt/myapp/test.txt || echo "custom software creation failed"

# Sleep and wake session
echo "📝 Step 6: Sleep session"
curl -s -X POST http://136.119.229.69/session/${SESSION_UUID}/sleep \
  -H "X-API-Key: your-secure-api-key-change-in-production"

sleep 15

echo "📝 Step 7: Wake session"
curl -s -X POST http://136.119.229.69/session/${SESSION_UUID}/wake \
  -H "X-API-Key: your-secure-api-key-change-in-production"

sleep 30

# Get new pod name
NEW_POD_NAME=$(kubectl get pod -n fresh-system -l uuid=${SESSION_UUID} -o jsonpath='{.items[0].metadata.name}')
echo "New pod name: $NEW_POD_NAME"

# Test if installations persisted
echo "📝 Step 8: Test if installations persisted"

echo "=== Testing pip package persistence ==="
kubectl exec -n fresh-system $NEW_POD_NAME -- pip list | grep requests || echo "❌ pip package NOT persistent"

echo "=== Testing custom software persistence ==="
kubectl exec -n fresh-system $NEW_POD_NAME -- cat /opt/myapp/test.txt || echo "❌ custom software NOT persistent"

echo "✅ Installation persistence test completed!"