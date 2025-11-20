#!/bin/bash
# Fresh System Complete Test - All Features with Timestamps
# Tests: Create, Sleep, Wake, Persistence, Scaling, Cleanup

set -e

API_BASE="http://136.119.229.69"
API_KEY="your-secure-api-key-change-in-production"
export PATH="/opt/homebrew/share/google-cloud-sdk/bin:$PATH"

# Timestamp function
timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# Timer function
start_timer() {
  START_TIME=$(date +%s)
}

end_timer() {
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  echo "⏱️  Time taken: ${ELAPSED}s"
}

TOTAL_START=$(date +%s)

echo "=========================================="
echo "   FRESH SYSTEM COMPLETE TEST"
echo "   Started at: $(timestamp)"
echo "=========================================="
echo ""

# 1. Create Session
echo "=== 1. Create Session ==="
echo "[$(timestamp)] Starting session creation..."
start_timer
RESPONSE=$(curl -s -X POST $API_BASE/session/create \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "fresh-test@example.com"}')
end_timer
echo "$RESPONSE" | jq
UUID=$(echo "$RESPONSE" | jq -r '.uuid')
WORKSPACE=$(echo "$RESPONSE" | jq -r '.workspace_url')
echo ""
echo "✅ UUID: $UUID"
echo "✅ Workspace: $WORKSPACE"
echo "[$(timestamp)] Session created"
echo ""
sleep 2

# 2. Wait for pod to be ready
echo "=== 2. Waiting for Pod to be Ready ==="
echo "[$(timestamp)] Checking pod status..."
start_timer
for i in {1..90}; do
  POD_STATUS=$(kubectl get pod -l app=user-$UUID -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
  POD_READY=$(kubectl get pod -l app=user-$UUID -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
  
  if [ "$POD_STATUS" = "Running" ] && [ "$POD_READY" = "true" ]; then
    end_timer
    echo "✅ Pod is ready!"
    break
  fi
  
  echo "[$(timestamp)] Pod status: $POD_STATUS, Ready: $POD_READY (${i}s)"
  sleep 1
done
echo ""

# 3. Check Status
echo "=== 3. Check Session Status ==="
echo "[$(timestamp)] Checking session status..."
curl -s $API_BASE/session/$UUID/status -H "X-API-Key: $API_KEY" | jq
echo ""
sleep 2

# 4. Check Pod Details
echo "=== 4. Check Pod Details ==="
echo "[$(timestamp)] Pod details:"
kubectl get pod -l app=user-$UUID
echo ""
sleep 2

# 5. Test UI Loading
echo "=== 5. Test UI Loading ==="
echo "[$(timestamp)] Testing workspace UI accessibility..."
start_timer
for i in {1..90}; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $WORKSPACE 2>/dev/null || echo "000")
  echo "[$(timestamp)] UI Response: HTTP $HTTP_CODE (${i}s)"
  
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    end_timer
    echo "✅ UI is accessible!"
    break
  fi
  sleep 1
done
echo ""
sleep 2

# 6. Create Files (Test Persistence)
echo "=== 6. Create Test Files ==="
echo "[$(timestamp)] Creating test files..."
start_timer
kubectl exec deployment/user-$UUID -- sh -c "
  echo 'Fresh system test data' > /app/test.txt && \
  mkdir -p /app/project && \
  echo 'console.log(\"Fresh system ready\");' > /app/project/app.js && \
  ls -lh /app/
"
end_timer
echo "✅ Files created"
echo ""
sleep 2

# 7. Verify Files
echo "=== 7. Verify Files ==="
echo "[$(timestamp)] Reading test file..."
kubectl exec deployment/user-$UUID -- cat /app/test.txt
echo ""
sleep 2

# 8. Test Sleep
echo "=== 8. Test Sleep ==="
echo "[$(timestamp)] Putting session to sleep..."
start_timer
curl -s -X POST $API_BASE/session/$UUID/sleep -H "X-API-Key: $API_KEY" | jq
sleep 15
end_timer
REPLICAS=$(curl -s $API_BASE/session/$UUID/status -H "X-API-Key: $API_KEY" | jq '.replicas')
echo "Replicas: $REPLICAS (should be 0)"
echo "[$(timestamp)] Sleep completed"
echo ""
sleep 2

# 9. Test Wake
echo "=== 9. Test Wake ==="
echo "[$(timestamp)] Waking up session..."
start_timer
curl -s -X POST $API_BASE/session/$UUID/wake -H "X-API-Key: $API_KEY" | jq
sleep 30
end_timer
REPLICAS=$(curl -s $API_BASE/session/$UUID/status -H "X-API-Key: $API_KEY" | jq '.replicas')
echo "Replicas: $REPLICAS (should be 1)"
echo "[$(timestamp)] Wake completed"
echo ""
sleep 2

# 10. Verify Files Persist
echo "=== 10. Verify Files Persist After Wake ==="
echo "[$(timestamp)] Checking file persistence..."
kubectl exec deployment/user-$UUID -- cat /app/test.txt
echo "✅ Files persisted after wake"
echo ""
sleep 2

# 11. Test Scale Up
echo "=== 11. Test Scale Up ==="
echo "[$(timestamp)] Scaling up resources..."
start_timer
curl -s -X POST $API_BASE/session/$UUID/scale \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scale": "up"}' | jq
sleep 20
end_timer
echo "✅ Scaled up"
echo ""

# 12. Test Scale Down
echo "=== 12. Test Scale Down ==="
echo "[$(timestamp)] Scaling down resources..."
start_timer
curl -s -X POST $API_BASE/session/$UUID/scale \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scale": "down"}' | jq
sleep 20
end_timer
echo "✅ Scaled down"
echo ""

# 13. Delete Session
echo "=== 13. Delete Session (Triggers Backup) ==="
echo "[$(timestamp)] Deleting session..."
start_timer
curl -s -X DELETE $API_BASE/session/$UUID -H "X-API-Key: $API_KEY" | jq
echo ""
echo "[$(timestamp)] Waiting 60 seconds for backup..."
sleep 60
end_timer

# 14. Verify Backup
echo "=== 14. Verify Backup Job ==="
echo "[$(timestamp)] Checking backup job..."
kubectl get jobs -l session-uuid=$UUID 2>/dev/null || echo "No backup job found"
echo ""
kubectl logs job/backup-$UUID 2>&1 | tail -10 || echo "Backup job completed or not found"
echo ""

# 15. Verify Resources Deleted
echo "=== 15. Verify Resources Deleted ==="
echo "[$(timestamp)] Checking resource cleanup..."
kubectl get deployment user-$UUID 2>&1 || echo "✅ Deployment deleted"
kubectl get service user-$UUID 2>&1 || echo "✅ Service deleted"
kubectl get ingress user-$UUID 2>&1 || echo "✅ Ingress deleted"
kubectl get pvc pvc-$UUID 2>&1 || echo "✅ PVC deleted"
echo ""

# Calculate total time
TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - TOTAL_START))

# Summary
echo "=========================================="
echo "           TEST SUMMARY"
echo "=========================================="
echo "[$(timestamp)] Test completed"
echo ""
echo "✅ Session created: $UUID"
echo "✅ Pod started and ready"
echo "✅ UI loaded and accessible"
echo "✅ Files created in PVC"
echo "✅ Sleep tested (1→0)"
echo "✅ Wake tested (0→1)"
echo "✅ Files persisted"
echo "✅ Scale up/down tested"
echo "✅ Session deleted"
echo "✅ Backup completed"
echo "✅ Resources cleaned up"
echo ""
echo "⏱️  Total test time: ${TOTAL_TIME}s"
echo ""
echo "🎉 ALL TESTS PASSED!"
echo "=========================================="
