#!/bin/bash
# CLIENT API PERSISTENCE TEST
# Tests persistence using only the session manager API endpoints

set -e

# Configuration
SESSION_MANAGER_URL="${SESSION_MANAGER_URL:-http://136.119.229.69}"
API_KEY="${API_KEY:-your-secure-api-key-change-in-production}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     PERSISTENCE VALIDATION TEST (API ONLY)                    ║"
echo "╔════════════════════════════════════════════════════════════════╗"
echo ""
echo "Session Manager: $SESSION_MANAGER_URL"
echo ""

# Step 1: Create session
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Creating new session"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RESPONSE=$(curl -s -X POST \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "persistence-test@example.com"}' \
  "$SESSION_MANAGER_URL/session/create")

SESSION_UUID=$(echo $RESPONSE | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4)
WORKSPACE_URL=$(echo $RESPONSE | grep -o '"workspace_url":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SESSION_UUID" ]; then
    echo "❌ Failed to create session"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "✓ Session created: $SESSION_UUID"
echo "✓ Workspace URL: $WORKSPACE_URL"
echo ""

# Step 2: Wait for pod to be ready
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Waiting for environment to be ready (60 seconds)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 60

# Step 3: Check session status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Checking session status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

STATUS=$(curl -s -H "X-API-Key: $API_KEY" "$SESSION_MANAGER_URL/session/$SESSION_UUID/status")
echo "$STATUS" | grep -q "created" && echo "✓ Session is active" || echo "⚠ Session status: $STATUS"
echo ""

# Step 4: Instructions for manual testing
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: MANUAL PERSISTENCE TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open your workspace: $WORKSPACE_URL"
echo ""
echo "2. In the terminal, install packages and create files:"
echo "   pip3 install --user requests"
echo "   npm install -g lodash --prefix /usr/local"
echo "   echo 'test data' > /app/myfile.txt"
echo "   echo 'user config' > /root/config.txt"
echo ""
echo "3. Press ENTER when done to test persistence..."
read -p ""

# Step 5: Put session to sleep
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Putting session to sleep (simulating restart)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SLEEP_RESPONSE=$(curl -s -X POST \
  -H "X-API-Key: $API_KEY" \
  "$SESSION_MANAGER_URL/session/$SESSION_UUID/sleep")

echo "$SLEEP_RESPONSE" | grep -q "sleeping" && echo "✓ Session put to sleep" || echo "Response: $SLEEP_RESPONSE"
echo "Waiting 30 seconds..."
sleep 30

# Step 6: Wake session
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Waking session (pod will restart)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WAKE_RESPONSE=$(curl -s -X POST \
  -H "X-API-Key: $API_KEY" \
  "$SESSION_MANAGER_URL/session/$SESSION_UUID/wake")

echo "$WAKE_RESPONSE" | grep -q "waking" && echo "✓ Session waking up" || echo "Response: $WAKE_RESPONSE"
echo "Waiting 60 seconds for pod to restart..."
sleep 60

# Step 7: Test scale UP
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 7: Scaling UP resources (to max: 2Gi RAM, 2 vCPU)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCALE_UP=$(curl -s -X POST \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scale_type": "up"}' \
  "$SESSION_MANAGER_URL/session/$SESSION_UUID/scale")

echo "$SCALE_UP" | grep -q "scaled" && echo "✓ Scaled UP successfully" || echo "Response: $SCALE_UP"
echo "Waiting 30 seconds for scaling..."
sleep 30

# Step 8: Test scale DOWN
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 8: Scaling DOWN resources (to min: 512Mi RAM, 0.5 vCPU)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCALE_DOWN=$(curl -s -X POST \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scale_type": "down"}' \
  "$SESSION_MANAGER_URL/session/$SESSION_UUID/scale")

echo "$SCALE_DOWN" | grep -q "scaled" && echo "✓ Scaled DOWN successfully" || echo "Response: $SCALE_DOWN"
echo "Waiting 30 seconds for scaling..."
sleep 30

# Step 9: Test chat API
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 9: Testing chat API"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CHAT_RESPONSE=$(curl -s -X POST \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from API test"}' \
  "$SESSION_MANAGER_URL/session/$SESSION_UUID/chat")

echo "$CHAT_RESPONSE" | grep -q "response" && echo "✓ Chat API working" || echo "Response: $CHAT_RESPONSE"

# Step 10: List all sessions
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 10: Listing all sessions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SESSIONS=$(curl -s -H "X-API-Key: $API_KEY" "$SESSION_MANAGER_URL/sessions")
echo "$SESSIONS" | grep -q "$SESSION_UUID" && echo "✓ Session found in list" || echo "Sessions: $SESSIONS"

# Step 11: Verify persistence
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 11: VERIFY PERSISTENCE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open your workspace again: $WORKSPACE_URL"
echo ""
echo "2. Verify your data persisted:"
echo "   python3 -c 'import requests; print(\"✓ requests package found\")"
echo "   ls /usr/local/lib/node_modules/lodash && echo '✓ lodash found'"
echo "   cat /app/myfile.txt"
echo "   cat /root/config.txt"
echo ""
echo "3. If all commands work, persistence is successful! ✅"
echo ""

# Step 12: Cleanup option
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CLEANUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Delete test session? (y/n): " DELETE

if [ "$DELETE" = "y" ]; then
    curl -s -X DELETE \
      -H "X-API-Key: $API_KEY" \
      "$SESSION_MANAGER_URL/session/$SESSION_UUID"
    echo "✓ Session deleted"
else
    echo "Session kept: $SESSION_UUID"
    echo "To delete later: curl -X DELETE -H 'X-API-Key: $API_KEY' $SESSION_MANAGER_URL/session/$SESSION_UUID"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     TEST COMPLETE                                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"