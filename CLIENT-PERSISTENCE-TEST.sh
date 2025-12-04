#!/bin/bash
# CLIENT PERSISTENCE VALIDATION TEST
# This script validates that system packages and user data persist across pod restarts

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     ENHANCED PERSISTENCE VALIDATION TEST                      ║"
echo "╔════════════════════════════════════════════════════════════════╗"
echo ""

# Get session UUID from user
read -p "Enter your session UUID (e.g., 05520e67): " SESSION_UUID

if [ -z "$SESSION_UUID" ]; then
    echo "❌ Error: Session UUID is required"
    exit 1
fi

NAMESPACE="default"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l uuid=$SESSION_UUID -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "❌ Error: No pod found for session $SESSION_UUID"
    exit 1
fi

echo "✓ Found pod: $POD_NAME"
echo ""

# Phase 1: Install packages and create test data
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 1: Installing packages and creating test data"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "1. Installing Python package (requests)..."
kubectl exec $POD_NAME -n $NAMESPACE -- pip3 install --user requests

echo "2. Installing npm package (lodash)..."
kubectl exec $POD_NAME -n $NAMESPACE -- npm install -g lodash --prefix /usr/local

echo "3. Creating test files in persistent directories..."
kubectl exec $POD_NAME -n $NAMESPACE -- sh -c "echo 'Client test data' > /app/client-test.txt"
kubectl exec $POD_NAME -n $NAMESPACE -- sh -c "echo 'User config data' > /root/user-config.txt"
kubectl exec $POD_NAME -n $NAMESPACE -- sh -c "echo 'Optional software' > /opt/software.txt"

echo "4. Creating test database file..."
kubectl exec $POD_NAME -n $NAMESPACE -- sh -c "echo 'Database test' > /data/db/test-db.txt"

echo ""
echo "✓ Phase 1 complete - packages installed and data created"
echo ""

# Phase 2: Restart pod
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 2: Restarting pod to test persistence"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Deleting pod..."
kubectl delete pod $POD_NAME -n $NAMESPACE

echo "Waiting for new pod to start..."
sleep 10

# Wait for new pod
kubectl wait --for=condition=Ready pod -l uuid=$SESSION_UUID -n $NAMESPACE --timeout=300s

NEW_POD_NAME=$(kubectl get pods -n $NAMESPACE -l uuid=$SESSION_UUID -o jsonpath='{.items[0].metadata.name}')
echo "✓ New pod ready: $NEW_POD_NAME"
echo ""

# Phase 3: Verify persistence
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 3: Verifying data persistence"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FAILED=0

echo "1. Checking Python package (requests)..."
if kubectl exec $NEW_POD_NAME -n $NAMESPACE -- python3 -c "import requests; print('✓ requests package found')" 2>/dev/null; then
    echo "   ✓ PASS: Python package persisted"
else
    echo "   ❌ FAIL: Python package not found"
    FAILED=1
fi

echo "2. Checking npm package (lodash)..."
if kubectl exec $NEW_POD_NAME -n $NAMESPACE -- test -d /usr/local/lib/node_modules/lodash 2>/dev/null; then
    echo "   ✓ PASS: npm package persisted"
else
    echo "   ❌ FAIL: npm package not found"
    FAILED=1
fi

echo "3. Checking test files..."
if kubectl exec $NEW_POD_NAME -n $NAMESPACE -- cat /app/client-test.txt 2>/dev/null | grep -q "Client test data"; then
    echo "   ✓ PASS: /app file persisted"
else
    echo "   ❌ FAIL: /app file not found"
    FAILED=1
fi

if kubectl exec $NEW_POD_NAME -n $NAMESPACE -- cat /root/user-config.txt 2>/dev/null | grep -q "User config data"; then
    echo "   ✓ PASS: /root file persisted"
else
    echo "   ❌ FAIL: /root file not found"
    FAILED=1
fi

if kubectl exec $NEW_POD_NAME -n $NAMESPACE -- cat /opt/software.txt 2>/dev/null | grep -q "Optional software"; then
    echo "   ✓ PASS: /opt file persisted"
else
    echo "   ❌ FAIL: /opt file not found"
    FAILED=1
fi

if kubectl exec $NEW_POD_NAME -n $NAMESPACE -- cat /data/db/test-db.txt 2>/dev/null | grep -q "Database test"; then
    echo "   ✓ PASS: /data/db file persisted"
else
    echo "   ❌ FAIL: /data/db file not found"
    FAILED=1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "✅ TEST PASSED: All data and packages persisted successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Your enhanced persistence is working correctly:"
    echo "  • Python packages persist across restarts"
    echo "  • npm packages persist across restarts"
    echo "  • User files persist across restarts"
    echo "  • Database data persists across restarts"
    exit 0
else
    echo "❌ TEST FAILED: Some data did not persist"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi