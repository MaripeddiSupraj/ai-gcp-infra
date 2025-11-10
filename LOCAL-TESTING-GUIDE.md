# 🧪 Local Testing Guide

## Simple Testing from Your Computer

### **Prerequisites**
- Terminal/Command Prompt
- `curl` command (built-in on Mac/Linux, install on Windows)

---

## 🚀 **Quick Test (Copy & Paste)**

### **Test 1: Health Check (No Auth)**
```bash
curl http://34.46.174.78/health
```

**Expected:**
```json
{"status":"healthy","redis":"healthy"}
```

---

### **Test 2: Create Session**
```bash
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "mytest@example.com"}'
```

**Expected:**
```json
{
  "uuid": "abc12345",
  "user_id": "mytest@example.com",
  "status": "created",
  "workspace_url": "vs-code-abc12345.example.com"
}
```

**Save the UUID!** You'll need it for next tests.

---

### **Test 3: Wake Pod**
```bash
# Replace abc12345 with YOUR uuid from Test 2
curl -X POST http://34.46.174.78/session/abc12345/wake \
  -H "X-API-Key: your-secure-api-key-change-in-production"
```

**Expected:**
```json
{
  "uuid": "abc12345",
  "action": "wake",
  "status": "queued"
}
```

---

### **Test 4: Check Status**
```bash
# Wait 20 seconds after wake, then check
curl http://34.46.174.78/session/abc12345/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"
```

**Expected:**
```json
{
  "uuid": "abc12345",
  "replicas": 1,
  "queue_length": 0
}
```

`replicas: 1` means pod is running!

---

### **Test 5: Send Chat Message**
```bash
curl -X POST http://34.46.174.78/session/abc12345/chat \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello AI!"}'
```

**Expected:**
```json
{
  "uuid": "abc12345",
  "status": "queued"
}
```

---

### **Test 6: Delete Session**
```bash
curl -X DELETE http://34.46.174.78/session/abc12345 \
  -H "X-API-Key: your-secure-api-key-change-in-production"
```

**Expected:**
```json
{
  "uuid": "abc12345",
  "status": "terminated"
}
```

---

## 🎯 **Complete Test Script**

Save this as `test-api.sh`:

```bash
#!/bin/bash

API_KEY="your-secure-api-key-change-in-production"
BASE_URL="http://34.46.174.78"

echo "🧪 Testing Session Manager API"
echo "================================"

# Test 1: Health
echo -e "\n1️⃣ Health Check..."
curl -s $BASE_URL/health | jq .

# Test 2: Create Session
echo -e "\n2️⃣ Creating Session..."
RESPONSE=$(curl -s -X POST $BASE_URL/session/create \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}')

echo $RESPONSE | jq .
UUID=$(echo $RESPONSE | jq -r .uuid)
echo "✅ UUID: $UUID"

# Test 3: Wake Pod
echo -e "\n3️⃣ Waking Pod..."
curl -s -X POST $BASE_URL/session/$UUID/wake \
  -H "X-API-Key: $API_KEY" | jq .

# Test 4: Wait and Check Status
echo -e "\n4️⃣ Waiting 25s for pod to start..."
sleep 25
curl -s $BASE_URL/session/$UUID/status \
  -H "X-API-Key: $API_KEY" | jq .

# Test 5: Send Chat
echo -e "\n5️⃣ Sending Chat Message..."
curl -s -X POST $BASE_URL/session/$UUID/chat \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello AI!"}' | jq .

# Test 6: Check Status Again
echo -e "\n6️⃣ Final Status Check..."
curl -s $BASE_URL/session/$UUID/status \
  -H "X-API-Key: $API_KEY" | jq .

echo -e "\n✅ All tests complete!"
echo "UUID for manual testing: $UUID"
echo "To delete: curl -X DELETE $BASE_URL/session/$UUID -H \"X-API-Key: $API_KEY\""
```

**Run it:**
```bash
chmod +x test-api.sh
./test-api.sh
```

---

## 🌐 **Using Postman**

### **Setup:**
1. Open Postman
2. Create new Collection: "Session Manager"
3. Add environment variable:
   - `API_KEY` = `your-secure-api-key-change-in-production`
   - `BASE_URL` = `http://34.46.174.78`

### **Request 1: Create Session**
- **Method:** POST
- **URL:** `{{BASE_URL}}/session/create`
- **Headers:**
  - `X-API-Key`: `{{API_KEY}}`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
  ```json
  {
    "user_id": "test@example.com"
  }
  ```
- **Click:** Send
- **Save UUID** from response

### **Request 2: Wake Pod**
- **Method:** POST
- **URL:** `{{BASE_URL}}/session/YOUR_UUID/wake`
- **Headers:**
  - `X-API-Key`: `{{API_KEY}}`
- **Click:** Send

### **Request 3: Get Status**
- **Method:** GET
- **URL:** `{{BASE_URL}}/session/YOUR_UUID/status`
- **Headers:**
  - `X-API-Key`: `{{API_KEY}}`
- **Click:** Send

---

## 🐍 **Using Python**

```python
import requests
import time

API_KEY = "your-secure-api-key-change-in-production"
BASE_URL = "http://34.46.174.78"

headers = {
    "X-API-Key": API_KEY,
    "Content-Type": "application/json"
}

# Test 1: Create Session
print("1️⃣ Creating session...")
response = requests.post(
    f"{BASE_URL}/session/create",
    headers=headers,
    json={"user_id": "test@example.com"}
)
data = response.json()
print(f"Response: {data}")

uuid = data['uuid']
workspace_url = data['workspace_url']
print(f"✅ UUID: {uuid}")
print(f"✅ Workspace: {workspace_url}")

# Test 2: Wake Pod
print("\n2️⃣ Waking pod...")
response = requests.post(
    f"{BASE_URL}/session/{uuid}/wake",
    headers={"X-API-Key": API_KEY}
)
print(f"Response: {response.json()}")

# Test 3: Wait and Check Status
print("\n3️⃣ Waiting 25s for pod...")
time.sleep(25)

response = requests.get(
    f"{BASE_URL}/session/{uuid}/status",
    headers={"X-API-Key": API_KEY}
)
status = response.json()
print(f"Status: {status}")
print(f"Pod replicas: {status['replicas']}")

# Test 4: Send Chat
print("\n4️⃣ Sending chat message...")
response = requests.post(
    f"{BASE_URL}/session/{uuid}/chat",
    headers=headers,
    json={"message": "Hello AI!"}
)
print(f"Response: {response.json()}")

print(f"\n✅ All tests complete!")
print(f"UUID: {uuid}")
```

**Run it:**
```bash
python test_api.py
```

---

## 🔍 **What to Check**

### **After Create Session:**
```bash
# Check Kubernetes resources
kubectl get deployment user-abc12345
kubectl get service user-abc12345
kubectl get scaledobject user-abc12345-scaler

# Should all exist
```

### **After Wake:**
```bash
# Wait 20 seconds, then check
kubectl get pods -l uuid=abc12345

# Should show 1 pod running
```

### **After 2 Minutes Idle:**
```bash
# Wait 2 minutes without sending messages
sleep 130

# Check pods
kubectl get pods -l uuid=abc12345

# Should show: No resources found (scaled to 0)
```

---

## ❌ **Common Errors**

### **Error: "API key required"**
```json
{"error": "API key required"}
```
**Fix:** Add `X-API-Key` header to your request

### **Error: "Invalid API key"**
```json
{"error": "Invalid API key"}
```
**Fix:** Use correct API key: `your-secure-api-key-change-in-production`

### **Error: Connection refused**
```
curl: (7) Failed to connect
```
**Fix:** Check if API is running:
```bash
kubectl get pods -l app=session-manager
```

---

## 📊 **Expected Behavior**

| Action | Time | Pod State | Cost |
|--------|------|-----------|------|
| Create session | 0s | 0 replicas (sleeping) | $0 |
| Wake pod | 0-20s | Starting | $0 |
| Pod ready | 20s | 1 replica (running) | $$ |
| Active chat | 20s-2min | Running | $$ |
| No activity | 2min | Scales to 0 | $0 |
| Wake again | 2min-2min20s | Starting | $0 |
| Active again | 2min20s+ | Running | $$ |

---

## 🎯 **Quick Verification**

```bash
# 1. Is API healthy?
curl http://34.46.174.78/health

# 2. Can I create session?
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}'

# 3. Did it return UUID and workspace_url?
# ✅ YES = Everything working!
# ❌ NO = Check API key or logs
```

---

## 🆘 **Troubleshooting**

### **Check API Logs:**
```bash
kubectl logs -l app=session-manager --tail=50
```

### **Check Pod Status:**
```bash
kubectl get pods -l app=session-manager
```

### **Check Service:**
```bash
kubectl get svc session-manager
```

### **Test from Inside Cluster:**
```bash
kubectl run test-pod --rm -it --image=curlimages/curl -- sh
# Inside pod:
curl http://session-manager/health
```

---

**Everything ready for testing! 🚀**
