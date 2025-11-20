#!/bin/bash
set -e

echo "🧪 Testing Multiple Paths Persistence"
echo "====================================="

# Configuration
API_KEY="your-secure-api-key-change-in-production"
SESSION_MANAGER_URL="http://localhost:5000"  # Change to your LoadBalancer IP
TEST_USER="test@example.com"

echo "📝 Step 1: Create test session"
RESPONSE=$(curl -s -X POST ${SESSION_MANAGER_URL}/session/create \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\": \"${TEST_USER}\"}")

SESSION_UUID=$(echo $RESPONSE | jq -r '.uuid')
echo "✅ Session created: ${SESSION_UUID}"

echo "📝 Step 2: Wait for pod to be ready"
sleep 30

echo "📝 Step 3: Check pod volume mounts"
kubectl get pod -n fresh-system -l uuid=${SESSION_UUID} -o yaml | grep -A 20 volumeMounts

echo "📝 Step 4: Verify PVC exists"
kubectl get pvc -n fresh-system pvc-${SESSION_UUID}

echo "📝 Step 5: Test file persistence in each path"
POD_NAME=$(kubectl get pod -n fresh-system -l uuid=${SESSION_UUID} -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo "❌ Pod not found"
    exit 1
fi

echo "Pod name: $POD_NAME"

# Test each mount path
echo "Testing /app path..."
kubectl exec -n fresh-system $POD_NAME -- sh -c "echo 'test-app-data' > /app/test-app.txt && ls -la /app/"

echo "Testing /root path..."
kubectl exec -n fresh-system $POD_NAME -- sh -c "echo 'test-root-data' > /root/test-root.txt && ls -la /root/"

echo "Testing /etc/supervisor path..."
kubectl exec -n fresh-system $POD_NAME -- sh -c "mkdir -p /etc/supervisor && echo 'test-supervisor-data' > /etc/supervisor/test-supervisor.txt && ls -la /etc/supervisor/"

echo "Testing /var/log path..."
kubectl exec -n fresh-system $POD_NAME -- sh -c "echo 'test-log-data' > /var/log/test-log.txt && ls -la /var/log/"

echo "Testing /data/db path..."
kubectl exec -n fresh-system $POD_NAME -- sh -c "mkdir -p /data/db && echo 'test-db-data' > /data/db/test-db.txt && ls -la /data/db/"

echo "📝 Step 6: Sleep the session"
curl -s -X POST ${SESSION_MANAGER_URL}/session/${SESSION_UUID}/sleep \
  -H "X-API-Key: ${API_KEY}"

echo "Waiting for pod to sleep..."
sleep 10

echo "📝 Step 7: Wake the session"
curl -s -X POST ${SESSION_MANAGER_URL}/session/${SESSION_UUID}/wake \
  -H "X-API-Key: ${API_KEY}"

echo "Waiting for pod to wake..."
sleep 30

echo "📝 Step 8: Verify data persistence after sleep/wake"
NEW_POD_NAME=$(kubectl get pod -n fresh-system -l uuid=${SESSION_UUID} -o jsonpath='{.items[0].metadata.name}')

echo "New pod name: $NEW_POD_NAME"

# Verify each path still has data
echo "Checking /app persistence..."
kubectl exec -n fresh-system $NEW_POD_NAME -- cat /app/test-app.txt

echo "Checking /root persistence..."
kubectl exec -n fresh-system $NEW_POD_NAME -- cat /root/test-root.txt

echo "Checking /etc/supervisor persistence..."
kubectl exec -n fresh-system $NEW_POD_NAME -- cat /etc/supervisor/test-supervisor.txt

echo "Checking /var/log persistence..."
kubectl exec -n fresh-system $NEW_POD_NAME -- cat /var/log/test-log.txt

echo "Checking /data/db persistence..."
kubectl exec -n fresh-system $NEW_POD_NAME -- cat /data/db/test-db.txt

echo "📝 Step 9: Cleanup test session"
curl -s -X DELETE ${SESSION_MANAGER_URL}/session/${SESSION_UUID} \
  -H "X-API-Key: ${API_KEY}"

echo "✅ Test completed successfully!"
echo "✅ All 5 paths (/app, /root, /etc/supervisor, /var/log, /data/db) persist correctly"