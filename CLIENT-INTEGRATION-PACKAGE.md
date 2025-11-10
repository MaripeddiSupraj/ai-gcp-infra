# 🚀 Client Integration Package

## 📦 What You Need to Provide

### 1. **API Base URL**
```
http://34.46.174.78
```
*(Replace with your production domain later)*

### 2. **API Key** (Share Securely!)
```
your-secure-api-key-change-in-production
```
**⚠️ IMPORTANT:** 
- Generate a new secure key for production: `openssl rand -base64 32`
- Share via secure channel (1Password, LastPass, encrypted email)
- Never commit to Git or share via Slack/Email

### 3. **API Endpoints Documentation**

#### **Create Session** (When user types first message)
```http
POST /session/create
Headers:
  X-API-Key: your-api-key-here
  Content-Type: application/json
Body:
  {"user_id": "user@example.com"}

Response:
{
  "uuid": "abc12345",
  "user_id": "user@example.com",
  "status": "created",
  "created_at": "2025-11-10T12:00:00Z"
}
```

#### **Wake Pod** (When user sends new message)
```http
POST /session/{uuid}/wake
Headers:
  X-API-Key: your-api-key-here

Response:
{
  "uuid": "abc12345",
  "action": "wake",
  "status": "queued"
}
```

#### **Get Status** (Check pod health)
```http
GET /session/{uuid}/status
Headers:
  X-API-Key: your-api-key-here

Response:
{
  "uuid": "abc12345",
  "session": {
    "user_id": "user@example.com",
    "status": "created",
    "created_at": "2025-11-10T12:00:00Z",
    "last_activity": "2025-11-10T12:05:00Z"
  },
  "queue_length": 0,
  "replicas": 1,
  "timestamp": "2025-11-10T12:05:30Z"
}
```

#### **Sleep Pod** (Manual sleep - optional)
```http
POST /session/{uuid}/sleep
Headers:
  X-API-Key: your-api-key-here

Response:
{
  "uuid": "abc12345",
  "action": "sleep",
  "status": "sleeping",
  "message": "Pod queued for sleep"
}
```

#### **Send Chat Message** (Route to user's pod)
```http
POST /session/{uuid}/chat
Headers:
  X-API-Key: your-api-key-here
  Content-Type: application/json
Body:
  {"message": "Hello AI!"}

Response:
{
  "uuid": "abc12345",
  "status": "queued",
  "message": "Pod is waking up, message queued"
}
```

#### **Delete Session** (Cleanup)
```http
DELETE /session/{uuid}
Headers:
  X-API-Key: your-api-key-here

Response:
{
  "uuid": "abc12345",
  "status": "terminated",
  "message": "Session and all resources deleted"
}
```

#### **Health Check** (No auth required)
```http
GET /health

Response:
{
  "status": "healthy",
  "redis": "healthy",
  "timestamp": "2025-11-10T12:00:00Z"
}
```

---

## 💻 Frontend Integration Example

### JavaScript/React Example
```javascript
const API_KEY = 'your-secure-api-key-change-in-production';
const BASE_URL = 'http://34.46.174.78';

class SessionManager {
  constructor() {
    this.apiKey = API_KEY;
    this.baseUrl = BASE_URL;
  }

  async createSession(userId) {
    const response = await fetch(`${this.baseUrl}/session/create`, {
      method: 'POST',
      headers: {
        'X-API-Key': this.apiKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ user_id: userId })
    });
    
    if (!response.ok) {
      throw new Error(`Failed to create session: ${response.statusText}`);
    }
    
    return await response.json();
  }

  async wakeSession(uuid) {
    const response = await fetch(`${this.baseUrl}/session/${uuid}/wake`, {
      method: 'POST',
      headers: {
        'X-API-Key': this.apiKey
      }
    });
    
    return await response.json();
  }

  async getStatus(uuid) {
    const response = await fetch(`${this.baseUrl}/session/${uuid}/status`, {
      headers: {
        'X-API-Key': this.apiKey
      }
    });
    
    return await response.json();
  }

  async sendMessage(uuid, message) {
    const response = await fetch(`${this.baseUrl}/session/${uuid}/chat`, {
      method: 'POST',
      headers: {
        'X-API-Key': this.apiKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ message })
    });
    
    return await response.json();
  }

  async deleteSession(uuid) {
    const response = await fetch(`${this.baseUrl}/session/${uuid}`, {
      method: 'DELETE',
      headers: {
        'X-API-Key': this.apiKey
      }
    });
    
    return await response.json();
  }
}

// Usage Example
const sessionManager = new SessionManager();

// When user logs in and types first message
async function handleFirstMessage(userId, message) {
  try {
    // 1. Create session
    const { uuid } = await sessionManager.createSession(userId);
    
    // 2. Store UUID in localStorage or state
    localStorage.setItem('sessionUuid', uuid);
    
    // 3. Display to user
    const subdomain = `vs-code-${uuid}.example.com`;
    console.log(`Your workspace: ${subdomain}`);
    
    // 4. Wake pod and send message
    await sessionManager.wakeSession(uuid);
    await sessionManager.sendMessage(uuid, message);
    
    return uuid;
  } catch (error) {
    console.error('Error creating session:', error);
  }
}

// When user sends subsequent messages
async function handleMessage(message) {
  const uuid = localStorage.getItem('sessionUuid');
  
  if (!uuid) {
    console.error('No active session');
    return;
  }
  
  try {
    // Wake pod if sleeping
    await sessionManager.wakeSession(uuid);
    
    // Send message
    const response = await sessionManager.sendMessage(uuid, message);
    console.log('Message sent:', response);
  } catch (error) {
    console.error('Error sending message:', error);
  }
}
```

---

## 🔄 User Flow Implementation

### Step 1: User Login
```javascript
// After successful login
const userId = user.email; // or user.id
```

### Step 2: First Message
```javascript
// When user types first message (e.g., "hi")
const { uuid } = await sessionManager.createSession(userId);

// Show user their workspace URL
const workspaceUrl = `https://vs-code-${uuid}.example.com`;
displayToUser(workspaceUrl);
```

### Step 3: Subsequent Messages
```javascript
// For every message after first
await sessionManager.wakeSession(uuid);
await sessionManager.sendMessage(uuid, userMessage);
```

### Step 4: Auto-Sleep
```
No action needed - pods automatically sleep after 2 minutes of inactivity
```

### Step 5: User Returns
```javascript
// When user sends new message after sleep
await sessionManager.wakeSession(uuid); // Pod wakes automatically
```

---

## 🎯 What Client Needs to Build

### ✅ Your Responsibility (Already Done)
- ✅ Per-user pod creation with UUID
- ✅ Pod sleep after 2 min idle
- ✅ Pod wake on new message
- ✅ REST APIs with authentication
- ✅ GKE cluster with auto-scaling

### ⚠️ Client's Responsibility
1. **Frontend UI**
   - Login/signup page
   - Chat interface
   - Display workspace URL: `vs-code-{uuid}.example.com`

2. **LLM Integration**
   - Integrate LLM (OpenAI, Anthropic, etc.) in user pods
   - Handle chat responses

3. **Database**
   - Store first message in their main database
   - Store user-to-UUID mapping

4. **DNS Setup**
   - Configure wildcard DNS: `*.example.com` → User pods
   - Or use subdomain routing

---

## 📊 API Behavior

| Scenario | API Call | Pod State | Response Time |
|----------|----------|-----------|---------------|
| First message | `POST /session/create` | Creates pod (0 replicas) | ~500ms |
| Wake pod | `POST /session/{uuid}/wake` | Scales 0→1 | ~20s |
| Active pod | `POST /session/{uuid}/chat` | Already running | ~100ms |
| After 2 min idle | Automatic | Scales 1→0 | Automatic |
| User returns | `POST /session/{uuid}/wake` | Scales 0→1 | ~20s |

---

## 🔒 Security Notes

1. **API Key**: Store securely, never expose in frontend code
2. **HTTPS**: Use HTTPS in production (not HTTP)
3. **Rate Limiting**: Already implemented (100 req/min per IP)
4. **CORS**: May need to configure if frontend is on different domain

---

## 🧪 Testing

### Test Without Authentication (Should Fail)
```bash
curl -X POST http://34.46.174.78/session/create \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}'

# Response: {"error": "API key required"}
```

### Test With Authentication (Should Work)
```bash
curl -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}'

# Response: {"uuid": "abc12345", "status": "created"}
```

---

## 📞 Support

If client has issues:
1. Check API key is correct
2. Verify all requests include `X-API-Key` header
3. Check `/health` endpoint (no auth required)
4. Review error messages in API responses

---

## ✅ Checklist for Client

- [ ] Received API base URL
- [ ] Received API key (securely)
- [ ] Tested API endpoints with Postman/curl
- [ ] Integrated into frontend code
- [ ] Tested full user flow (create → wake → chat → sleep)
- [ ] Set up DNS for `vs-code-*.example.com`
- [ ] Integrated LLM in user pods
- [ ] Storing first message in database
- [ ] Ready for production!

---

**Everything is ready on our end. Client can start integration immediately!** 🚀
