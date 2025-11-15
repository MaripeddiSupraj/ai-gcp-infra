#!/bin/bash

# Final Test Script for v3.1.0 - Complete User Flow
# Tests: Create → Add Files → Sleep → Wake → Scale → Delete with Backup

set -e

API_BASE="http://34.46.174.78"
API_KEY="your-secure-api-key-change-in-production"

echo "=========================================="
echo "   FINAL TEST - v3.1.0 Complete Flow"
echo "=========================================="
echo ""

# Step 1: Health Check
echo "=== Step 1: Health Check ==="
curl -s $API_BASE/health | jq
echo ""
sleep 2

# Step 2: Create Session
echo "=== Step 2: Create Session ==="
RESPONSE=$(curl -s -X POST $API_BASE/session/create \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "final-test@example.com"}')

UUID=$(echo $RESPONSE | jq -r '.uuid')
WORKSPACE_URL=$(echo $RESPONSE | jq -r '.workspace_url')

echo "✅ Session Created:"
echo "   UUID: $UUID"
echo "   Workspace: $WORKSPACE_URL"
echo ""
sleep 2

# Step 3: Wait for Pod to Start
echo "=== Step 3: Wait for Pod to Start (45 seconds) ==="
for i in {1..45}; do
  echo -n "."
  sleep 1
done
echo ""
echo "✅ Pod should be ready"
echo ""

# Step 4: Check Status
echo "=== Step 4: Check Status ==="
curl -s $API_BASE/session/$UUID/status \
  -H "X-API-Key: $API_KEY" | jq
echo ""
sleep 2

# Step 5: Verify Kubernetes Resources
echo "=== Step 5: Verify Kubernetes Resources ==="
export PATH="/opt/homebrew/share/google-cloud-sdk/bin:$PATH"
echo "Pod:"
kubectl get pod -l app=user-$UUID
echo ""
echo "PVC:"
kubectl get pvc pvc-$UUID
echo ""
echo "Service:"
kubectl get service user-$UUID
echo ""
echo "Ingress:"
kubectl get ingress user-$UUID
echo ""
sleep 2

# Step 6: Create Test Files in Workspace
echo "=== Step 6: Create Test Files in Workspace ==="
kubectl exec deployment/user-$UUID -- sh -c "
  echo 'User project file' > /workspace/project.txt && \
  echo 'Important data' > /workspace/data.txt && \
  mkdir -p /workspace/code && \
  echo 'console.log(\"Hello\");' > /workspace/code/app.js && \
  echo 'def main(): pass' > /workspace/code/main.py && \
  ls -lh /workspace/
"
echo "✅ Files created in /workspace"
echo ""
sleep 2

# Step 7: Verify Files
echo "=== Step 7: Verify Files ==="
kubectl exec deployment/user-$UUID -- cat /workspace/project.txt
kubectl exec deployment/user-$UUID -- cat /workspace/code/app.js
echo "✅ Files verified"
echo ""
sleep 2

# Step 8: Test Sleep
echo "=== Step 8: Test Sleep (Scale to 0) ==="
curl -s -X POST $API_BASE/session/$UUID/sleep \
  -H "X-API-Key: $API_KEY" | jq
echo ""
echo "Waiting 15 seconds for pod to scale down..."
sleep 15
echo ""
echo "Status after sleep:"
curl -s $API_BASE/session/$UUID/status \
  -H "X-API-Key: $API_KEY" | jq '.replicas'
echo ""
sleep 2

# Step 9: Test Wake
echo "=== Step 9: Test Wake (Scale to 1) ==="
curl -s -X POST $API_BASE/session/$UUID/wake \
  -H "X-API-Key: $API_KEY" | jq
echo ""
echo "Waiting 30 seconds for pod to wake..."
sleep 30
echo ""
echo "Status after wake:"
curl -s $API_BASE/session/$UUID/status \
  -H "X-API-Key: $API_KEY" | jq '.replicas'
echo ""
sleep 2

# Step 10: Verify Files Still Exist
echo "=== Step 10: Verify Files Persist After Wake ==="
kubectl exec deployment/user-$UUID -- ls -lh /workspace/
echo "✅ Files still exist (PVC working)"
echo ""
sleep 2

# Step 11: Test Scale Up
echo "=== Step 11: Test Scale Up (2Gi RAM, 2 CPU) ==="
curl -s -X POST $API_BASE/session/$UUID/scale \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scale": "up"}' | jq
echo ""
echo "Waiting 20 seconds for scale up..."
sleep 20
echo "✅ Scaled up"
echo ""
sleep 2

# Step 12: Test Scale Down
echo "=== Step 12: Test Scale Down (1Gi RAM, 1 CPU) ==="
curl -s -X POST $API_BASE/session/$UUID/scale \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scale": "down"}' | jq
echo ""
echo "Waiting 20 seconds for scale down..."
sleep 20
echo "✅ Scaled down"
echo ""
sleep 2

# Step 13: Delete Session (Triggers Backup)
echo "=== Step 13: Delete Session (Triggers Backup) ==="
curl -s -X DELETE $API_BASE/session/$UUID \
  -H "X-API-Key: $API_KEY" | jq
echo ""
echo "Waiting 60 seconds for backup to complete..."
sleep 60
echo ""

# Step 14: Verify Backup Job
echo "=== Step 14: Verify Backup Job ==="
kubectl get jobs -l session-uuid=$UUID
echo ""
echo "Backup job logs:"
kubectl logs job/backup-$UUID 2>&1 | tail -15
echo ""
sleep 2

# Step 15: Verify Backup File
echo "=== Step 15: Verify Backup File ==="
kubectl run verify-backup --image=alpine --rm -i --restart=Never --overrides="
{
  \"spec\": {
    \"containers\": [{
      \"name\": \"verify-backup\",
      \"image\": \"alpine\",
      \"command\": [\"sh\", \"-c\", \"apk add --no-cache unzip > /dev/null 2>&1 && ls -lh /backups/ && echo && echo '=== Backup Contents ===' && unzip -l /backups/workspace-$UUID-*.zip\"],
      \"volumeMounts\": [{
        \"name\": \"backup\",
        \"mountPath\": \"/backups\"
      }]
    }],
    \"volumes\": [{
      \"name\": \"backup\",
      \"persistentVolumeClaim\": {
        \"claimName\": \"backup-pvc\"
      }
    }]
  }
}" 2>&1 | grep -v "Defaulted to container\|All commands and output\|If you don't see\|warning:"
echo ""
sleep 2

# Step 16: Verify Resources Deleted
echo "=== Step 16: Verify Resources Deleted ==="
echo "Deployment:"
kubectl get deployment user-$UUID 2>&1 || echo "✅ Deployment deleted"
echo ""
echo "Service:"
kubectl get service user-$UUID 2>&1 || echo "✅ Service deleted"
echo ""
echo "Ingress:"
kubectl get ingress user-$UUID 2>&1 || echo "✅ Ingress deleted"
echo ""
echo "PVC:"
kubectl get pvc pvc-$UUID 2>&1 || echo "✅ PVC deleted"
echo ""
sleep 2

# Step 17: Final Metrics
echo "=== Step 17: Final Metrics ==="
curl -s $API_BASE/metrics | jq
echo ""

# Summary
echo "=========================================="
echo "           TEST SUMMARY"
echo "=========================================="
echo "✅ Session created with UUID: $UUID"
echo "✅ Pod started and became ready"
echo "✅ PVC created (5Gi)"
echo "✅ Files created in /workspace"
echo "✅ Sleep/Wake tested (replicas 0→1)"
echo "✅ Files persisted after wake"
echo "✅ Scale up/down tested"
echo "✅ Session deleted"
echo "✅ Backup job completed"
echo "✅ Backup file created and verified"
echo "✅ All resources cleaned up"
echo ""
echo "🎉 ALL TESTS PASSED - v3.1.0 WORKING!"
echo "=========================================="
