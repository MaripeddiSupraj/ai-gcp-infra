# Session-Based Pod Architecture for AI Chat Platform

## 🎯 Business Requirements

Build an AI chat platform (like Lovable/Bolt) where:
1. User logs into website → Gets unique session UUID
2. User says "hi" → Dedicated pod spins up for that user
3. Pod handles all LLM chat requests for that user
4. Pod goes to sleep after idle timeout (cost optimization)
5. User clicks "wake up" → Same pod (with UUID) resumes chat
6. Each session is isolated with its own pod

## 🏗️ Architecture Overview

```
User Browser
    ↓
Frontend (abc.com)
    ↓
API Gateway / Ingress
    ↓
Session Manager API
    ↓
Redis (Session State)
    ↓
GKE Autopilot (Per-User Pods)
    ↓
LLM Backend
```

## 📦 Components

### 1. **Session Manager API** (Python/FastAPI)
**Purpose**: Orchestrate pod lifecycle per user session

**Endpoints**:
- `POST /session/create` - Create UUID, spin up pod
- `GET /session/{uuid}/status` - Check pod status (active/sleeping/terminated)
- `POST /session/{uuid}/wake` - Wake up sleeping pod
- `POST /session/{uuid}/chat` - Route chat to user's pod
- `DELETE /session/{uuid}` - Terminate session and cleanup

**Responsibilities**:
- Generate unique session UUIDs
- Create Kubernetes Jobs/Pods with UUID labels
- Track pod state in Redis
- Handle pod lifecycle (create, sleep, wake, terminate)
- Route requests to correct pod

### 2. **Redis (Memorystore)**
**Purpose**: Fast session state management

**Data Structure**:
```json
{
  "session:uuid-123": {
    "podName": "chat-pod-uuid-123",
    "status": "active|sleeping|terminated",
    "createdAt": "2025-11-05T10:00:00Z",
    "lastActivity": "2025-11-05T10:15:00Z",
    "userId": "user-456",
    "chatHistory": "gs://bucket/sessions/uuid-123/history.json"
  }
}
```

**TTL**: 24 hours (auto-cleanup old sessions)

### 3. **KEDA (Kubernetes Event Driven Autoscaling)**
**Purpose**: Scale pods based on Redis queue/events

**Triggers**:
- Redis stream for new chat messages
- HTTP requests to session endpoint
- Scale to zero after 15 min idle
- Wake up on new message

**Configuration**:
```yaml
scaleTargetRef:
  name: chat-pod-{uuid}
minReplicaCount: 0
maxReplicaCount: 1
triggers:
  - type: redis
    metadata:
      address: redis:6379
      listName: chat-queue-{uuid}
      listLength: "1"
```

### 4. **Chat Pod (Per User)**
**Purpose**: Handle LLM chat for single user

**Specifications**:
- **Image**: Custom chat app with LLM integration
- **Resources**: 
  - Requests: 500m CPU, 1Gi RAM
  - Limits: 2 CPU, 4Gi RAM
- **Labels**: `session-uuid: {uuid}`, `user-id: {userId}`
- **Lifecycle**:
  - Startup: Load chat history from Cloud Storage
  - Active: Process chat requests
  - Idle: Scale to zero after 15 min
  - Wake: Restore from saved state

### 5. **Cloud Storage (GCS)**
**Purpose**: Persist chat history per session

**Structure**:
```
gs://chat-sessions/
  ├── uuid-123/
  │   ├── history.json
  │   ├── context.json
  │   └── metadata.json
  └── uuid-456/
      └── ...
```

### 6. **Ingress Controller (Nginx/GKE Ingress)**
**Purpose**: Route requests to correct pod

**Configuration**:
- Session affinity based on UUID cookie
- Route `/chat/{uuid}/*` to pod with label `session-uuid={uuid}`
- Fallback to Session Manager if pod not found

## 🔄 User Flow

### Flow 1: New User Session
```
1. User visits abc.com
2. Frontend calls: POST /session/create
3. Session Manager:
   - Generates UUID: "uuid-123"
   - Creates Redis entry: status="pending"
   - Returns UUID to frontend
4. Frontend stores UUID in cookie/localStorage
5. User says "hi"
6. Frontend calls: POST /session/uuid-123/chat {"message": "hi"}
7. Session Manager:
   - Creates Kubernetes Job: chat-pod-uuid-123
   - Updates Redis: status="active", podName="chat-pod-uuid-123"
   - Waits for pod to be ready
   - Routes chat request to pod
8. Pod processes chat with LLM
9. Returns response to user
```

### Flow 2: Active Chat
```
1. User sends message
2. Frontend calls: POST /session/uuid-123/chat {"message": "..."}
3. Session Manager:
   - Checks Redis: status="active"
   - Routes directly to pod: chat-pod-uuid-123
4. Pod processes and responds
5. Updates lastActivity in Redis
```

### Flow 3: Pod Goes to Sleep
```
1. No activity for 15 minutes
2. KEDA detects idle pod
3. KEDA scales pod to zero
4. Before termination, pod:
   - Saves chat history to GCS
   - Saves context/state to GCS
5. Session Manager updates Redis: status="sleeping"
```

### Flow 4: Wake Up Pod
```
1. User clicks "wake up" or sends new message
2. Frontend calls: POST /session/uuid-123/wake
3. Session Manager:
   - Checks Redis: status="sleeping"
   - Creates new pod: chat-pod-uuid-123
   - Pod loads history from GCS
   - Updates Redis: status="active"
4. Routes chat request to pod
5. User continues conversation
```

### Flow 5: Session Cleanup
```
1. After 24 hours or user logout
2. Session Manager:
   - Deletes pod
   - Archives chat history to cold storage
   - Removes Redis entry
```

## 💰 Cost Analysis

### Per User Session Cost

| Component | Active (1 hour) | Sleeping | Monthly (10 sessions/day) |
|-----------|----------------|----------|---------------------------|
| GKE Autopilot Pod | $0.05 | $0 | $15 |
| Redis (Memorystore) | - | - | $30 (shared) |
| Cloud Storage | $0.001 | $0.001 | $0.30 |
| Ingress/LB | - | - | $20 (shared) |
| **Total per user** | **$0.05/hr** | **$0** | **~$0.50/user/month** |

### Scaling Estimates

| Users | Active Pods | Monthly Cost |
|-------|-------------|--------------|
| 100 | 10-20 avg | $500 |
| 1,000 | 100-200 avg | $5,000 |
| 10,000 | 1,000-2,000 avg | $50,000 |

**Cost Optimization**:
- Autopilot: Pay only for active pods
- Scale to zero: No cost when sleeping
- Spot instances: 70% cheaper (if using Standard GKE)
- Aggressive idle timeout: Reduce active time

## 🚀 Implementation Phases

### Phase 1: Foundation (Week 1)
- [x] GKE Autopilot cluster
- [x] Cost optimization (scale to zero)
- [x] Monitoring (Prometheus/Grafana)
- [ ] Redis (Memorystore) setup
- [ ] Cloud Storage bucket

### Phase 2: Core Components (Week 2)
- [ ] Session Manager API
  - Session CRUD operations
  - Pod lifecycle management
  - Redis integration
- [ ] Chat Pod template
  - Base Docker image
  - LLM integration
  - State persistence
- [ ] KEDA installation
  - Redis scaler
  - HTTP scaler

### Phase 3: Integration (Week 3)
- [ ] Ingress configuration
- [ ] Session routing
- [ ] Pod-to-pod communication
- [ ] Chat history persistence
- [ ] Wake-up mechanism

### Phase 4: Production Ready (Week 4)
- [ ] Auto-cleanup jobs
- [ ] Monitoring dashboards
- [ ] Cost tracking per session
- [ ] Load testing
- [ ] Security hardening

## 🔒 Security Considerations

1. **Pod Isolation**: Network policies between user pods
2. **Authentication**: JWT tokens for session validation
3. **Data Encryption**: Encrypt chat history at rest
4. **Resource Limits**: Prevent resource exhaustion
5. **Rate Limiting**: Prevent abuse
6. **Secrets Management**: Use Workload Identity for GCS access

## 📊 Monitoring & Observability

### Metrics to Track
- Active sessions count
- Sleeping sessions count
- Pod creation time
- Pod wake-up time
- Chat latency per session
- Cost per session
- LLM token usage per session

### Grafana Dashboards
- Session lifecycle overview
- Per-user pod metrics
- Cost analysis dashboard
- LLM usage dashboard

## 🎯 Success Criteria

1. Pod spins up in < 10 seconds
2. Pod wakes up in < 5 seconds
3. 99.9% uptime for active sessions
4. Cost < $1 per user per month
5. Support 10,000 concurrent users
6. Chat history persists across sleep/wake cycles

## 📝 Next Steps

1. **Review & Approve** this architecture
2. **Provision Redis** (Memorystore)
3. **Build Session Manager API**
4. **Create Chat Pod template**
5. **Install KEDA**
6. **Test end-to-end flow**

---

**Questions for Client:**
1. What LLM are you using? (OpenAI, Anthropic, custom?)
2. Average chat session duration?
3. Expected concurrent users?
4. Chat history retention period?
5. Budget constraints?
