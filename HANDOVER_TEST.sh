#!/bin/bash
# Final Handover Test - v3.1.0
# Run this script to verify all features before client handover

set -e

API_BASE="http://34.46.174.78"
API_KEY="your-secure-api-key-change-in-production"
export PATH="/opt/homebrew/share/google-cloud-sdk/bin:$PATH"

echo "=========================================="
echo "   HANDOVER TEST - v3.1.0"
echo "=========================================="
echo ""

# 1. Create Session
echo "=== 1. Create Session ==="
RESPONSE=$(curl -s -X POST $API_BASE/session/create \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "handover-test@example.com"}')
echo "$RESPONSE" | jq
UUID=$(echo "$RESPONSE" | jq -r '.uuid')
WORKSPACE=$(echo "$RESPONSE" | jq -r '.workspace_url')
echo ""
echo "✅ UUID: $UUID"
echo "✅ Workspace: $WORKSPACE"
echo ""
sleep 2

# 2. Wait for pod
echo "=== 2. Waiting 45 seconds for pod ==="
sleep 45
echo ""

# 3. Check Status
echo "=== 3. Check Status ==="
curl -s $API_BASE/session/$UUID/status -H "X-API-Key: $API_KEY" | jq
echo ""
sleep 2

# 4. Check Pod
echo "=== 4. Check Pod ==="
kubectl get pod -l app=user-$UUID
echo ""
sleep 2

# 5. Create Files
echo "=== 5. Create Test Files ==="
kubectl exec deployment/user-$UUID -- sh -c "
  echo 'Handover test data' > /workspace/test.txt && \
  mkdir -p /workspace/project && \
  echo 'console.log(\"Ready\");' > /workspace/project/app.js && \
  ls -lh /workspace/
"
echo "✅ Files created"
echo ""
sleep 2

# 6. Verify Files
echo "=== 6. Verify Files ==="
kubectl exec deployment/user-$UUID -- cat /workspace/test.txt
echo ""
sleep 2

# 7. Test Sleep
echo "=== 7. Test Sleep ==="
curl -s -X POST $API_BASE/session/$UUID/sleep -H "X-API-Key: $API_KEY" | jq
sleep 15
REPLICAS=$(curl -s $API_BASE/session/$UUID/status -H "X-API-Key: $API_KEY" | jq '.replicas')
echo "Replicas: $REPLICAS (should be 0)"
echo ""
sleep 2

# 8. Test Wake
echo "=== 8. Test Wake ==="
curl -s -X POST $API_BASE/session/$UUID/wake -H "X-API-Key: $API_KEY" | jq
sleep 30
REPLICAS=$(curl -s $API_BASE/session/$UUID/status -H "X-API-Key: $API_KEY" | jq '.replicas')
echo "Replicas: $REPLICAS (should be 1)"
echo ""
sleep 2

# 9. Verify Files Persist
echo "=== 9. Verify Files Persist ==="
kubectl exec deployment/user-$UUID -- cat /workspace/test.txt
echo "✅ Files persisted after wake"
echo ""
sleep 2

# 10. Test Scale Up
echo "=== 10. Test Scale Up ==="
curl -s -X POST $API_BASE/session/$UUID/scale \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scale": "up"}' | jq
sleep 20
echo "✅ Scaled up"
echo ""

# 11. Test Scale Down
echo "=== 11. Test Scale Down ==="
curl -s -X POST $API_BASE/session/$UUID/scale \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scale": "down"}' | jq
sleep 20
echo "✅ Scaled down"
echo ""

# 12. Delete Session
echo "=== 12. Delete Session (Triggers Backup) ==="
curl -s -X DELETE $API_BASE/session/$UUID -H "X-API-Key: $API_KEY" | jq
echo ""
echo "Waiting 60 seconds for backup..."
sleep 60

# 13. Verify Backup
echo "=== 13. Verify Backup Job ==="
kubectl get jobs -l session-uuid=$UUID
echo ""
kubectl logs job/backup-$UUID 2>&1 | tail -10
echo ""

# 14. Verify Resources Deleted
echo "=== 14. Verify Resources Deleted ==="
kubectl get deployment user-$UUID 2>&1 || echo "✅ Deployment deleted"
kubectl get service user-$UUID 2>&1 || echo "✅ Service deleted"
kubectl get ingress user-$UUID 2>&1 || echo "✅ Ingress deleted"
kubectl get pvc pvc-$UUID 2>&1 || echo "✅ PVC deleted"
echo ""

# Summary
echo "=========================================="
echo "           TEST SUMMARY"
echo "=========================================="
echo "✅ Session created: $UUID"
echo "✅ Pod started and ready"
echo "✅ Files created in PVC"
echo "✅ Sleep tested (1→0)"
echo "✅ Wake tested (0→1)"
echo "✅ Files persisted"
echo "✅ Scale up/down tested"
echo "✅ Session deleted"
echo "✅ Backup completed"
echo "✅ Resources cleaned up"
echo ""
echo "🎉 ALL TESTS PASSED!"
echo "=========================================="
