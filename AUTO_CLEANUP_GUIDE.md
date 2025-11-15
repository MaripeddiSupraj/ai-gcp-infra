# Automatic Pod Cleanup Guide

## Problem
User leaves chat → Pod keeps running → Wasting money

## Solution
Your backend must track user activity and call DELETE API when user is inactive.

---

## Option 1: Simple Timeout (Recommended)

Track last activity timestamp for each user session.

### Implementation (Node.js Example)

```javascript
const sessions = new Map(); // Store: uuid -> { userId, lastActivity, workspaceUrl }

// When user sends message
async function handleUserMessage(userId, message) {
  const session = getUserSession(userId);
  
  // Update last activity
  sessions.set(session.uuid, {
    ...session,
    lastActivity: Date.now()
  });
  
  // Forward message to session-manager
  await axios.post(`http://34.46.174.78/session/${session.uuid}/chat`, 
    { message },
    { headers: { 'X-API-Key': 'your-secure-api-key-change-in-production' } }
  );
}

// Background job - runs every 5 minutes
setInterval(async () => {
  const now = Date.now();
  const INACTIVE_TIMEOUT = 30 * 60 * 1000; // 30 minutes
  
  for (const [uuid, session] of sessions.entries()) {
    const inactiveTime = now - session.lastActivity;
    
    if (inactiveTime > INACTIVE_TIMEOUT) {
      console.log(`Deleting inactive session: ${uuid}`);
      
      // Call DELETE API
      await axios.delete(`http://34.46.174.78/session/${uuid}`,
        { headers: { 'X-API-Key': 'your-secure-api-key-change-in-production' } }
      );
      
      // Remove from tracking
      sessions.delete(uuid);
    }
  }
}, 5 * 60 * 1000); // Check every 5 minutes
```

---

## Option 2: Sleep Then Delete

More cost-effective: Sleep after 15 min, delete after 24 hours.

```javascript
const SLEEP_TIMEOUT = 15 * 60 * 1000;  // 15 minutes
const DELETE_TIMEOUT = 24 * 60 * 60 * 1000; // 24 hours

setInterval(async () => {
  const now = Date.now();
  
  for (const [uuid, session] of sessions.entries()) {
    const inactiveTime = now - session.lastActivity;
    
    // Sleep after 15 minutes
    if (inactiveTime > SLEEP_TIMEOUT && session.status !== 'sleeping') {
      console.log(`Sleeping session: ${uuid}`);
      
      await axios.post(`http://34.46.174.78/session/${uuid}/sleep`,
        {},
        { headers: { 'X-API-Key': 'your-secure-api-key-change-in-production' } }
      );
      
      session.status = 'sleeping';
      session.sleptAt = now;
    }
    
    // Delete after 24 hours of sleep
    if (session.status === 'sleeping' && (now - session.sleptAt) > DELETE_TIMEOUT) {
      console.log(`Deleting old session: ${uuid}`);
      
      await axios.delete(`http://34.46.174.78/session/${uuid}`,
        { headers: { 'X-API-Key': 'your-secure-api-key-change-in-production' } }
      );
      
      sessions.delete(uuid);
    }
  }
}, 5 * 60 * 1000);
```

---

## Option 3: User Logout Event

Delete immediately when user explicitly logs out.

```javascript
// When user clicks "Logout" or closes chat
async function handleUserLogout(userId) {
  const session = getUserSession(userId);
  
  if (session) {
    console.log(`User logged out, deleting session: ${session.uuid}`);
    
    // Call DELETE API
    await axios.delete(`http://34.46.174.78/session/${session.uuid}`,
      { headers: { 'X-API-Key': 'your-secure-api-key-change-in-production' } }
    );
    
    sessions.delete(session.uuid);
  }
}
```

---

## Complete Example (All Options Combined)

```javascript
const axios = require('axios');

const API_BASE = 'http://34.46.174.78';
const API_KEY = 'your-secure-api-key-change-in-production';

class SessionManager {
  constructor() {
    this.sessions = new Map(); // uuid -> session data
    this.userToSession = new Map(); // userId -> uuid
    
    // Start cleanup job
    this.startCleanupJob();
  }
  
  // Create session when user starts chat
  async createSession(userId) {
    const response = await axios.post(`${API_BASE}/session/create`,
      { user_id: userId },
      { headers: { 'X-API-Key': API_KEY } }
    );
    
    const session = {
      uuid: response.data.uuid,
      userId: userId,
      workspaceUrl: response.data.workspace_url,
      createdAt: Date.now(),
      lastActivity: Date.now(),
      status: 'active'
    };
    
    this.sessions.set(session.uuid, session);
    this.userToSession.set(userId, session.uuid);
    
    return session;
  }
  
  // Update activity when user sends message
  updateActivity(userId) {
    const uuid = this.userToSession.get(userId);
    if (uuid) {
      const session = this.sessions.get(uuid);
      if (session) {
        session.lastActivity = Date.now();
        
        // Wake if sleeping
        if (session.status === 'sleeping') {
          this.wakeSession(uuid);
        }
      }
    }
  }
  
  // Sleep session
  async sleepSession(uuid) {
    const session = this.sessions.get(uuid);
    if (!session) return;
    
    await axios.post(`${API_BASE}/session/${uuid}/sleep`,
      {},
      { headers: { 'X-API-Key': API_KEY } }
    );
    
    session.status = 'sleeping';
    session.sleptAt = Date.now();
    console.log(`✅ Session sleeping: ${uuid}`);
  }
  
  // Wake session
  async wakeSession(uuid) {
    const session = this.sessions.get(uuid);
    if (!session) return;
    
    await axios.post(`${API_BASE}/session/${uuid}/wake`,
      {},
      { headers: { 'X-API-Key': API_KEY } }
    );
    
    session.status = 'active';
    console.log(`✅ Session woken: ${uuid}`);
  }
  
  // Delete session
  async deleteSession(uuid) {
    const session = this.sessions.get(uuid);
    if (!session) return;
    
    await axios.delete(`${API_BASE}/session/${uuid}`,
      { headers: { 'X-API-Key': API_KEY } }
    );
    
    this.userToSession.delete(session.userId);
    this.sessions.delete(uuid);
    console.log(`✅ Session deleted: ${uuid}`);
  }
  
  // Background cleanup job
  startCleanupJob() {
    setInterval(async () => {
      const now = Date.now();
      const SLEEP_AFTER = 15 * 60 * 1000;  // 15 minutes
      const DELETE_AFTER = 24 * 60 * 60 * 1000; // 24 hours
      
      for (const [uuid, session] of this.sessions.entries()) {
        try {
          const inactiveTime = now - session.lastActivity;
          
          // Sleep after 15 minutes of inactivity
          if (session.status === 'active' && inactiveTime > SLEEP_AFTER) {
            console.log(`⏰ Sleeping inactive session: ${uuid}`);
            await this.sleepSession(uuid);
          }
          
          // Delete after 24 hours of sleep
          if (session.status === 'sleeping') {
            const sleepTime = now - session.sleptAt;
            if (sleepTime > DELETE_AFTER) {
              console.log(`🗑️ Deleting old session: ${uuid}`);
              await this.deleteSession(uuid);
            }
          }
        } catch (error) {
          console.error(`Error processing session ${uuid}:`, error.message);
        }
      }
    }, 5 * 60 * 1000); // Run every 5 minutes
  }
  
  // Handle user logout
  async handleLogout(userId) {
    const uuid = this.userToSession.get(userId);
    if (uuid) {
      console.log(`👋 User logged out: ${userId}`);
      await this.deleteSession(uuid);
    }
  }
}

// Usage
const manager = new SessionManager();

// When user starts chat
app.post('/chat/start', async (req, res) => {
  const { userId } = req.body;
  const session = await manager.createSession(userId);
  res.json({ workspaceUrl: session.workspaceUrl });
});

// When user sends message
app.post('/chat/message', async (req, res) => {
  const { userId, message } = req.body;
  manager.updateActivity(userId);
  // ... forward message to session pod
});

// When user logs out
app.post('/chat/logout', async (req, res) => {
  const { userId } = req.body;
  await manager.handleLogout(userId);
  res.json({ success: true });
});
```

---

## Recommended Timings

| Scenario | Sleep After | Delete After | Cost Savings |
|----------|-------------|--------------|--------------|
| **Aggressive** | 5 min | 1 hour | 95% |
| **Balanced** | 15 min | 24 hours | 80% |
| **Conservative** | 30 min | 7 days | 60% |

---

## Database Tracking (Optional)

Store sessions in database for persistence across restarts:

```sql
CREATE TABLE user_sessions (
  uuid VARCHAR(8) PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  workspace_url TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT NOW(),
  last_activity TIMESTAMP DEFAULT NOW(),
  slept_at TIMESTAMP NULL,
  INDEX idx_user_id (user_id),
  INDEX idx_last_activity (last_activity)
);
```

```javascript
// Update activity in DB
async function updateActivity(userId) {
  await db.query(
    'UPDATE user_sessions SET last_activity = NOW() WHERE user_id = ?',
    [userId]
  );
}

// Cleanup job queries DB
async function cleanupJob() {
  // Find sessions to sleep
  const toSleep = await db.query(`
    SELECT uuid FROM user_sessions 
    WHERE status = 'active' 
    AND last_activity < NOW() - INTERVAL 15 MINUTE
  `);
  
  for (const row of toSleep) {
    await sleepSession(row.uuid);
  }
  
  // Find sessions to delete
  const toDelete = await db.query(`
    SELECT uuid FROM user_sessions 
    WHERE status = 'sleeping' 
    AND slept_at < NOW() - INTERVAL 24 HOUR
  `);
  
  for (const row of toDelete) {
    await deleteSession(row.uuid);
  }
}
```

---

## Testing

```bash
# 1. Create session
UUID=$(curl -s -X POST http://34.46.174.78/session/create \
  -H "X-API-Key: your-secure-api-key-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test@example.com"}' | jq -r '.uuid')

echo "Created: $UUID"

# 2. Wait 16 minutes (simulate inactivity)
# Your cleanup job should sleep it

# 3. Check status
curl http://34.46.174.78/session/$UUID/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"
# Should show: replicas: 0

# 4. Wait 24 hours
# Your cleanup job should delete it

# 5. Check if deleted
curl http://34.46.174.78/session/$UUID/status \
  -H "X-API-Key: your-secure-api-key-change-in-production"
# Should show: Session not found
```

---

## Summary

**The session-manager API does NOT auto-delete pods.**

**You must implement cleanup in your backend:**

1. ✅ Track user activity timestamps
2. ✅ Run background job every 5 minutes
3. ✅ Sleep pods after 15 min inactivity
4. ✅ Delete pods after 24 hours of sleep
5. ✅ Delete immediately on user logout

This gives you full control over cost optimization!
