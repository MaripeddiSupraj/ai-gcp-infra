# Client Architecture - Session-Based AI Chat Platform

## User Flow

### 1. User Login & Landing Page
- User visits: `abc.com` (client's domain)
- Sign up/login completed
- Lands on chat interface

### 2. First Message Trigger
- User types "hi" or any message in chat box
- **Backend Action**: 
  - Create dedicated pod for this user
  - Generate UUID for the session
  - Return UUID to frontend

### 3. VS Code Access
- Frontend redirects/opens: `vs-code-uuid-abc.com`
- User sees their code files in VS Code interface
- All prompts go to their dedicated pod
- Pod responds with code changes/responses

### 4. Idle Sleep
- If no messages for few minutes → Pod goes to sleep (scale to 0)
- Saves cost when user inactive

### 5. Wake Up on Return
- User comes back and sends new prompt
- Pod wakes up automatically
- Session continues with same UUID
- User sees their previous code/context

## Technical Components Needed

### Infrastructure (Your Responsibility) ✅
- [x] GKE Autopilot cluster
- [x] VPC networking
- [x] Artifact Registry
- [x] Cloud Storage (for session persistence)
- [x] Workload Identity
- [ ] KEDA for scale-to-zero
- [ ] Redis for session state
- [ ] Ingress with UUID-based routing

### Application (Client's Team Responsibility)
- [ ] Session Manager API (creates pods, manages UUID)
- [ ] Frontend chat interface
- [ ] VS Code web integration
- [ ] LLM integration for code generation
- [ ] WebSocket/SSE for real-time communication

## Architecture Diagram

```
User → abc.com (Frontend)
         ↓
    [First Message]
         ↓
    Session Manager API
         ↓
    Create Pod (UUID: abc-123)
         ↓
    Return UUID to Frontend
         ↓
    Redirect: vs-code-abc-123.abc.com
         ↓
    Ingress (routes by UUID)
         ↓
    User's Dedicated Pod
         ↓
    [Idle 5 mins] → KEDA scales to 0
         ↓
    [New Message] → KEDA scales to 1
```

## What We Need to Build

### 1. KEDA ScaledObject
- Scale to 0 when idle
- Scale to 1 on Redis queue message
- Per-user pod lifecycle

### 2. Redis Deployment
- Store session state
- Queue for KEDA triggers
- Track active sessions

### 3. Ingress Configuration
- Route `vs-code-{uuid}.abc.com` → correct pod
- Session affinity
- SSL/TLS termination

### 4. StatefulSet/Deployment Template
- One pod per user session
- Persistent volume for code files
- Environment variables: UUID, user_id

### 5. Session Manager (Minimal Demo)
- API endpoint: POST /session/create
- Creates pod with UUID
- Returns UUID to frontend
- Stores session in Redis

## Next Steps (After Terraform Completes)

1. Deploy Redis
2. Deploy KEDA
3. Create session-based deployment template
4. Configure ingress for UUID routing
5. Build minimal Session Manager API
6. Test: Create session → Get UUID → Access pod → Sleep → Wake up
