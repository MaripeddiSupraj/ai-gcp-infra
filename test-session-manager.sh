#!/bin/bash
set -e

API="http://34.46.174.78"

echo "🧪 Testing Session Manager API"
echo "================================"

# 1. Health check
echo -e "\n1️⃣ Health Check..."
curl -s $API/health | jq .

# 2. Create session
echo -e "\n2️⃣ Creating session..."
RESPONSE=$(curl -s -X POST $API/session/create \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}')
echo $RESPONSE | jq .

UUID=$(echo $RESPONSE | jq -r .uuid)
echo "✅ UUID: $UUID"

# 3. Check resources
echo -e "\n3️⃣ Checking Kubernetes resources..."
kubectl get deployment user-$UUID
kubectl get service user-$UUID
kubectl get scaledobject user-$UUID-scaler

# 4. Wake pod
echo -e "\n4️⃣ Waking pod..."
curl -s -X POST $API/session/$UUID/wake | jq .

# 5. Wait and check status
echo -e "\n5️⃣ Waiting 20s for pod to start..."
sleep 20
curl -s $API/session/$UUID/status | jq .
kubectl get pods -l uuid=$UUID

# 6. Test chat
echo -e "\n6️⃣ Sending chat message..."
curl -s -X POST $API/session/$UUID/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello AI!"}' | jq .

# 7. Check metrics
echo -e "\n7️⃣ Checking metrics..."
curl -s $API/metrics | jq .

echo -e "\n✅ All tests passed!"
echo "UUID for manual testing: $UUID"
echo "To cleanup: curl -X DELETE $API/session/$UUID"
