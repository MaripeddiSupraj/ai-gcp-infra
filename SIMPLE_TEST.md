# Simple Final Test - v3.1.0

Run these commands one by one to test the complete flow.

## Step 1: Health Check
```bash
curl -s http://34.46.174.78/health | jq
```
Expected: `"version": "3.1.0"`, `"status": "healthy"`

---

## Step 2: Create Session
```bash
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}' | jq

# Save the UUID
UUID="<paste-uuid-here>"
```
Expected: Returns `uuid`, `workspace_url`, `status: created`

---

## Step 3: Wait for Pod (45 seconds)
```bash
sleep 45
```

---

## Step 4: Check Status
```bash
curl http://34.46.174.78/session/$UUID/status \
  -H "X-API-Key: your-secure-api-key-change-in-production" | jq
```
Expected: `"replicas": 1`

---

## Step 5: Verify Kubernetes Resources
```bash
export PATH="/opt/homebrew/share/google-cloud-sdk/bin:$PATH"

# Pod
kubectl get pod -l app=user-$UUID

# PVC
kubectl get pvc pvc-$UUID

# Service
kubectl get service user-$UUID

# Ingress
kubectl get ingress user-$UUID
```
Expected: All resources exist and pod is Running

---

## Step 6: Create Test Files
```bash
kubectl exec deployment/user-$UUID -- sh -c "
  echo 'Important data' > /workspace/data.txt && \
  echo 'User code' > /workspace/code.txt && \
  mkdir -p /workspace/project && \
  echo 'console.log(\"test\");' > /workspace/project/app.js && \
  ls -lh /workspace/
"
```
Expected: Files created successfully

---

## Step 7: Verify Files
```bash
kubectl exec deployment/user-$UUID -- cat /workspace/data.txt
kubectl exec deployment/user-$UUID -- cat /workspace/project/app.js
```
Expected: File contents displayed

---

## Step 8: Test Sleep
```bash
curl -X POST http://34.46.174.78/session/$UUID/sleep \
  -H "X-API-Key: your-secure-api-key-change-in-production" | jq

# Wait
sleep 15

# Check replicas
curl http://34.46.174.78/session/$UUID/status \
  -H "X-API-Key: your-secure-api-key-change-in-production" | jq '.replicas'
```
Expected: `0` (pod sleeping)

---

## Step 9: Test Wake
```bash
curl -X POST http://34.46.174.78/session/$UUID/wake \
  -H "X-API-Key: your-secure-api-key-change-in-production" | jq

# Wait
sleep 30

# Check replicas
curl http://34.46.174.78/session/$UUID/status \
  -H "X-API-Key: your-secure-api-key-change-in-production" | jq '.replicas'
```
Expected: `1` (pod running)

---

## Step 10: Verify Files Persist
```bash
kubectl exec deployment/user-$UUID -- ls -lh /workspace/
kubectl exec deployment/user-$UUID -- cat /workspace/data.txt
```
Expected: Files still exist (PVC working!)

---

## Step 11: Test Scale Up
```bash
curl -X POST http://34.46.174.78/session/$UUID/scale \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"scale": "up"}' | jq

sleep 20
```
Expected: `"action": "scale_up"`

---

## Step 12: Test Scale Down
```bash
curl -X POST http://34.46.174.78/session/$UUID/scale \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"scale": "down"}' | jq

sleep 20
```
Expected: `"action": "scale_down"`

---

## Step 13: Delete Session (Triggers Backup)
```bash
curl -X DELETE http://34.46.174.78/session/$UUID \
  -H "X-API-Key: your-secure-api-key-change-in-production" | jq

# Wait for backup
sleep 60
```
Expected: `"status": "terminated"`

---

## Step 14: Verify Backup Job
```bash
kubectl get jobs -l session-uuid=$UUID

kubectl logs job/backup-$UUID
```
Expected: Job completed, logs show "Backup completed for {uuid}"

---

## Step 15: Verify Backup File
```bash
kubectl run check-backup --image=alpine --rm -i --restart=Never --overrides="
{
  \"spec\": {
    \"containers\": [{
      \"name\": \"check-backup\",
      \"image\": \"alpine\",
      \"command\": [\"sh\", \"-c\", \"apk add --no-cache unzip > /dev/null 2>&1 && ls -lh /backups/ && echo && unzip -l /backups/workspace-$UUID-*.zip\"],
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
}"
```
Expected: Shows backup zip file with all workspace files

---

## Step 16: Verify Resources Deleted
```bash
kubectl get deployment user-$UUID 2>&1 || echo "Deleted"
kubectl get service user-$UUID 2>&1 || echo "Deleted"
kubectl get ingress user-$UUID 2>&1 || echo "Deleted"
kubectl get pvc pvc-$UUID 2>&1 || echo "Deleted"
```
Expected: All resources deleted

---

## Summary Checklist

- [ ] Session created with UUID
- [ ] Pod started and became ready
- [ ] PVC created (5Gi)
- [ ] Files created in /workspace
- [ ] Sleep tested (replicas → 0)
- [ ] Wake tested (replicas → 1)
- [ ] Files persisted after wake
- [ ] Scale up/down tested
- [ ] Session deleted
- [ ] Backup job completed
- [ ] Backup file verified
- [ ] All resources cleaned up

**If all checked: v3.1.0 is working perfectly! 🎉**
