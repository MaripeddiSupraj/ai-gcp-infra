#!/bin/bash
# Final Enhanced Persistence Test

echo "🎯 FINAL PERSISTENCE TEST"
echo "========================="

# Delete old test session first
echo "🗑️ Cleaning up old test session..."
curl -X DELETE -H "X-API-Key: your-secure-api-key-change-in-production" \
  http://136.119.229.69/session/7022d9ac

sleep 10

# Create new session with enhanced persistence
echo "🆕 Creating new session with enhanced persistence..."
RESPONSE=$(curl -s -X POST -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "final-test@example.com"}' \
  http://136.119.229.69/session/create)

echo "Response: $RESPONSE"

# Extract session UUID
SESSION_UUID=$(echo $RESPONSE | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4)
echo "Session UUID: $SESSION_UUID"

if [ -z "$SESSION_UUID" ]; then
    echo "❌ Failed to create session"
    exit 1
fi

# Wait for pod to be ready
echo "⏳ Waiting for pod to be ready..."
sleep 60

# Get pod name
POD_NAME=$(kubectl get pods -n fresh-system -l uuid=$SESSION_UUID -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD_NAME"

if [ -z "$POD_NAME" ]; then
    echo "❌ Pod not found"
    exit 1
fi

# Wait for pod to be running
kubectl wait --for=condition=Ready pod/$POD_NAME -n fresh-system --timeout=300s

echo ""
echo "🔍 Checking Volume Mounts..."
kubectl describe pod $POD_NAME -n fresh-system | grep -A 15 "Mounts:"

echo ""
echo "✅ ENHANCED PERSISTENCE TEST COMPLETE"
echo "======================================"