#!/bin/bash
set -e

echo "📦 PACKAGE INSTALLATION PERSISTENCE TEST"
echo "======================================="

# Create new session
echo "📝 Step 1: Create new session"
RESPONSE=$(curl -s -X POST http://136.119.229.69/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-package-persistence@example.com"}')

SESSION_UUID=$(echo $RESPONSE | jq -r '.uuid')
echo "✅ Session created: $SESSION_UUID"

# Wait for pod
echo "📝 Step 2: Wait for pod to be ready (45s)"
sleep 45

# Get pod name
POD_NAME=$(kubectl get pod -n fresh-system -l uuid=${SESSION_UUID} -o jsonpath='{.items[0].metadata.name}')
echo "Pod name: $POD_NAME"

# Install packages BEFORE sleep
echo "📝 Step 3: Install packages BEFORE sleep"

echo "Installing pip package 'requests'..."
kubectl exec -n fresh-system $POD_NAME -- pip install requests
echo "✅ pip package installed"

echo "Installing custom file in /opt..."
kubectl exec -n fresh-system $POD_NAME -- sh -c "mkdir -p /opt/myapp && echo 'Hello World' > /opt/myapp/test.txt"
echo "✅ Custom file created"

echo "Installing file in /usr/local..."
kubectl exec -n fresh-system $POD_NAME -- sh -c "echo 'local software' > /usr/local/myfile.txt"
echo "✅ Local file created"

# Verify installations
echo "📝 Step 4: Verify installations BEFORE sleep"
echo "=== pip list ==="
kubectl exec -n fresh-system $POD_NAME -- pip list | grep requests || echo "❌ requests not found"

echo "=== /opt/myapp/test.txt ==="
kubectl exec -n fresh-system $POD_NAME -- cat /opt/myapp/test.txt || echo "❌ custom file not found"

echo "=== /usr/local/myfile.txt ==="
kubectl exec -n fresh-system $POD_NAME -- cat /usr/local/myfile.txt || echo "❌ local file not found"

# Sleep session
echo "📝 Step 5: Sleep session"
curl -s -X POST http://136.119.229.69/session/${SESSION_UUID}/sleep \
  -H "X-API-Key: your-secure-api-key-change-in-production"

echo "Waiting for session to sleep (15s)..."
sleep 15

# Wake session
echo "📝 Step 6: Wake session"
curl -s -X POST http://136.119.229.69/session/${SESSION_UUID}/wake \
  -H "X-API-Key: your-secure-api-key-change-in-production"

echo "Waiting for session to wake (30s)..."
sleep 30

# Get new pod name
NEW_POD_NAME=$(kubectl get pod -n fresh-system -l uuid=${SESSION_UUID} -o jsonpath='{.items[0].metadata.name}')
echo "New pod name after wake: $NEW_POD_NAME"

# Test if packages persisted AFTER sleep
echo "📝 Step 7: Test if packages persisted AFTER sleep"

echo "=== Testing pip package persistence ==="
kubectl exec -n fresh-system $NEW_POD_NAME -- pip list | grep requests && echo "✅ pip package PERSISTED" || echo "❌ pip package LOST"

echo "=== Testing custom file persistence ==="
kubectl exec -n fresh-system $NEW_POD_NAME -- cat /opt/myapp/test.txt && echo "✅ custom file PERSISTED" || echo "❌ custom file LOST"

echo "=== Testing local file persistence ==="
kubectl exec -n fresh-system $NEW_POD_NAME -- cat /usr/local/myfile.txt && echo "✅ local file PERSISTED" || echo "❌ local file LOST"

echo ""
echo "🎯 SUMMARY:"
echo "- If packages are PERSISTED = System installation persistence is WORKING ✅"
echo "- If packages are LOST = System installation persistence is NOT WORKING ❌"
echo ""
echo "Test completed!"