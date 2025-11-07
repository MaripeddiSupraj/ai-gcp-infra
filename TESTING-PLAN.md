# Testing Plan for Session-Based Pod Architecture

## 🧪 Testing Strategy

### Phase 1: Component Testing (Current - Can Test Now)

#### 1.1 Test GKE Autopilot Cluster ✅
```bash
# Already working - verify
kubectl get nodes
kubectl get pods -A
```

#### 1.2 Test Monitoring ✅
```bash
# Already deployed
# Grafana: http://34.42.37.69
# Username: admin / Password: ChangeMe123!
```

#### 1.3 Test Scale to Zero (Can Test Now)
```bash
# Scale down current deployment to 0
kubectl scale deployment ai-environment --replicas=0

# Wait 2 minutes, verify pods terminated
kubectl get pods

# Scale back up
kubectl scale deployment ai-environment --replicas=2

# Verify pods created
kubectl get pods -w
```

### Phase 2: Redis Testing (Need to Deploy)

#### 2.1 Deploy Redis
```bash
# Using Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis bitnami/redis \
  --namespace default \
  --set auth.enabled=false \
  --set master.persistence.size=1Gi
```

#### 2.2 Test Redis Connection
```bash
# Connect to Redis
kubectl run redis-client --rm -it --image=redis:7 -- bash
redis-cli -h redis-master

# Test commands
SET session:test-123 "active"
GET session:test-123
DEL session:test-123
```

### Phase 3: KEDA Testing (Need to Deploy)

#### 3.1 Install KEDA
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace
```

#### 3.2 Test KEDA Scale to Zero
```bash
# Create test deployment with KEDA
kubectl apply -f test-keda-deployment.yaml

# Verify it scales to 0
kubectl get pods -w

# Trigger scale up (add message to Redis)
redis-cli -h redis-master LPUSH test-queue "message"

# Verify pod scales up
kubectl get pods -w
```

### Phase 4: Session Manager API Testing (Need to Build)

#### 4.1 Build Simple Session Manager
```python
# session-manager/app.py
from fastapi import FastAPI
from kubernetes import client, config
import redis
import uuid

app = FastAPI()
config.load_incluster_config()
k8s = client.CoreV1Api()
r = redis.Redis(host='redis-master', port=6379)

@app.post("/session/create")
def create_session():
    session_id = str(uuid.uuid4())
    r.set(f"session:{session_id}", "pending")
    return {"session_id": session_id, "status": "pending"}

@app.get("/session/{session_id}/status")
def get_status(session_id: str):
    status = r.get(f"session:{session_id}")
    return {"session_id": session_id, "status": status}
```

#### 4.2 Test Session Manager
```bash
# Deploy Session Manager
kubectl apply -f session-manager-deployment.yaml

# Test create session
curl -X POST http://session-manager/session/create

# Test get status
curl http://session-manager/session/{uuid}/status
```

### Phase 5: End-to-End Testing

#### 5.1 Test Complete Flow
```bash
# 1. Create session
SESSION_ID=$(curl -X POST http://session-manager/session/create | jq -r '.session_id')

# 2. Send first message (should create pod)
curl -X POST http://session-manager/session/$SESSION_ID/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "hi"}'

# 3. Verify pod created
kubectl get pods -l session-uuid=$SESSION_ID

# 4. Wait 15 minutes (or reduce timeout for testing)
sleep 900

# 5. Verify pod scaled to zero
kubectl get pods -l session-uuid=$SESSION_ID

# 6. Wake up pod
curl -X POST http://session-manager/session/$SESSION_ID/wake

# 7. Verify pod recreated
kubectl get pods -l session-uuid=$SESSION_ID -w
```

## 🚀 Quick Demo (Can Do Now)

### Demo 1: Manual Pod Lifecycle Test

Let me create a simple test to demonstrate the concept:

```bash
# 1. Create a test pod with UUID label
kubectl run chat-pod-test-123 \
  --image=nginx \
  --labels="session-uuid=test-123,app=chat-pod" \
  --requests="cpu=100m,memory=128Mi"

# 2. Verify pod running
kubectl get pods -l session-uuid=test-123

# 3. Simulate "sleep" - delete pod
kubectl delete pod chat-pod-test-123

# 4. Simulate "wake" - recreate pod with same UUID
kubectl run chat-pod-test-123 \
  --image=nginx \
  --labels="session-uuid=test-123,app=chat-pod" \
  --requests="cpu=100m,memory=128Mi"

# 5. Verify same UUID pod is back
kubectl get pods -l session-uuid=test-123
```

### Demo 2: HPA Scale to Zero Test

```bash
# 1. Check current replicas
kubectl get deployment ai-environment

# 2. Scale to 0
kubectl scale deployment ai-environment --replicas=0

# 3. Watch pods terminate
kubectl get pods -w

# 4. Check in Grafana - pod metrics should disappear

# 5. Scale back to 2
kubectl scale deployment ai-environment --replicas=2

# 6. Watch pods create
kubectl get pods -w

# 7. Check in Grafana - pod metrics should reappear
```

## 📊 What to Show Client

### Demo Script for Client Meeting

**1. Show Current Infrastructure (5 min)**
```bash
# Show GKE cluster
gcloud container clusters describe primary-cluster-v2 --region us-central1

# Show running pods
kubectl get pods -o wide

# Show Grafana monitoring
# Open: http://34.42.37.69
# Navigate to: Dashboards → Kubernetes Pods
```

**2. Demonstrate Scale to Zero (5 min)**
```bash
# Current state: 2 pods running
kubectl get pods

# Scale to zero
kubectl scale deployment ai-environment --replicas=0

# Show cost savings: $0 when no pods
kubectl get pods

# Scale back up
kubectl scale deployment ai-environment --replicas=2

# Show pods coming back
kubectl get pods -w
```

**3. Show Architecture Diagram (10 min)**
- Open ARCHITECTURE.md
- Explain user flow
- Show cost analysis
- Discuss implementation timeline

**4. Discuss Next Steps (10 min)**
- Questions about LLM integration
- Expected user load
- Budget approval
- Timeline for Phase 2

## 🎯 Success Metrics to Demonstrate

1. **Pod Creation Time**: < 10 seconds ✅
2. **Scale to Zero**: Works ✅
3. **Monitoring**: Per-pod metrics visible ✅
4. **Cost Optimization**: Autopilot + scale to zero ✅

## 📝 Client Questions to Ask

1. Which LLM provider? (OpenAI, Anthropic, custom)
2. Average session duration?
3. Expected concurrent users?
4. Budget per user?
5. When do you need this live?

---

**Ready to test?** Which demo do you want to run first?

1. **Demo 1**: Manual pod lifecycle (5 min)
2. **Demo 2**: Scale to zero test (5 min)
3. **Deploy Redis**: Start Phase 2 (15 min)
4. **Show client**: Architecture review (30 min)
