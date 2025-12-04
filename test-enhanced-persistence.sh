#!/bin/bash
# Enhanced Persistence Test Script

SESSION_UUID="7022d9ac"
POD_NAME="user-${SESSION_UUID}-6b74d8b8dd-k2d7x"
NAMESPACE="fresh-system"

echo "🧪 ENHANCED PERSISTENCE TEST"
echo "================================"
echo "Pod: $POD_NAME"
echo "Session: $SESSION_UUID"
echo ""

# Test 1: Check mount points
echo "📁 TEST 1: Verify Mount Points"
echo "------------------------------"
kubectl exec $POD_NAME -n $NAMESPACE -- df -h | grep -E "(app|root|usr/local|var/lib/dpkg|opt|data/db|var/log)"

echo ""
echo "📦 TEST 2: Install System Packages"
echo "-----------------------------------"
# Install system package
kubectl exec $POD_NAME -n $NAMESPACE -- apt update
kubectl exec $POD_NAME -n $NAMESPACE -- apt install -y htop tree

echo ""
echo "🐍 TEST 3: Install Python Packages"
echo "-----------------------------------"
# Install Python packages to user directory
kubectl exec $POD_NAME -n $NAMESPACE -- pip install --user requests beautifulsoup4

echo ""
echo "📦 TEST 4: Install Node Packages"
echo "---------------------------------"
# Install global npm packages
kubectl exec $POD_NAME -n $NAMESPACE -- npm install -g typescript lodash

echo ""
echo "💾 TEST 5: Create Test Files"
echo "-----------------------------"
# Create test files in persistent directories
kubectl exec $POD_NAME -n $NAMESPACE -- bash -c 'echo "Test app data" > /app/test-app.txt'
kubectl exec $POD_NAME -n $NAMESPACE -- bash -c 'echo "Test root data" > /root/test-root.txt'
kubectl exec $POD_NAME -n $NAMESPACE -- bash -c 'echo "Test opt data" > /opt/test-opt.txt'

echo ""
echo "🗄️ TEST 6: MongoDB Data"
echo "------------------------"
# Create MongoDB test data
kubectl exec $POD_NAME -n $NAMESPACE -- bash -c 'mkdir -p /data/db && echo "MongoDB test data" > /data/db/test-mongo.txt'

echo ""
echo "📋 TEST 7: Pre-Restart Verification"
echo "------------------------------------"
echo "Installed packages:"
kubectl exec $POD_NAME -n $NAMESPACE -- which htop
kubectl exec $POD_NAME -n $NAMESPACE -- which tree
kubectl exec $POD_NAME -n $NAMESPACE -- pip list --user | grep -E "(requests|beautifulsoup4)"
kubectl exec $POD_NAME -n $NAMESPACE -- npm list -g --depth=0 | grep -E "(typescript|lodash)"

echo ""
echo "Created files:"
kubectl exec $POD_NAME -n $NAMESPACE -- ls -la /app/test-app.txt
kubectl exec $POD_NAME -n $NAMESPACE -- ls -la /root/test-root.txt
kubectl exec $POD_NAME -n $NAMESPACE -- ls -la /opt/test-opt.txt
kubectl exec $POD_NAME -n $NAMESPACE -- ls -la /data/db/test-mongo.txt

echo ""
echo "🔄 TEST 8: Restart Pod (Delete & Recreate)"
echo "-------------------------------------------"
echo "Deleting pod to test persistence..."
kubectl delete pod $POD_NAME -n $NAMESPACE

echo "Waiting for new pod to start..."
sleep 30

# Get new pod name
NEW_POD=$(kubectl get pods -n $NAMESPACE -l uuid=$SESSION_UUID -o jsonpath='{.items[0].metadata.name}')
echo "New pod: $NEW_POD"

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/$NEW_POD -n $NAMESPACE --timeout=300s

echo ""
echo "✅ TEST 9: Post-Restart Verification"
echo "-------------------------------------"
echo "Checking if packages survived restart:"
kubectl exec $NEW_POD -n $NAMESPACE -- which htop || echo "❌ htop not found"
kubectl exec $NEW_POD -n $NAMESPACE -- which tree || echo "❌ tree not found"
kubectl exec $NEW_POD -n $NAMESPACE -- pip list --user | grep -E "(requests|beautifulsoup4)" || echo "❌ Python packages not found"
kubectl exec $NEW_POD -n $NAMESPACE -- npm list -g --depth=0 | grep -E "(typescript|lodash)" || echo "❌ Node packages not found"

echo ""
echo "Checking if files survived restart:"
kubectl exec $NEW_POD -n $NAMESPACE -- cat /app/test-app.txt || echo "❌ App file not found"
kubectl exec $NEW_POD -n $NAMESPACE -- cat /root/test-root.txt || echo "❌ Root file not found"
kubectl exec $NEW_POD -n $NAMESPACE -- cat /opt/test-opt.txt || echo "❌ Opt file not found"
kubectl exec $NEW_POD -n $NAMESPACE -- cat /data/db/test-mongo.txt || echo "❌ MongoDB file not found"

echo ""
echo "🎯 PERSISTENCE TEST COMPLETE"
echo "============================="