#!/bin/bash
# PROFESSIONAL PERSISTENCE TEST SUITE

SESSION_UUID="05520e67"
NAMESPACE="default"

echo "========================================="
echo "PROFESSIONAL PERSISTENCE TEST"
echo "Session: $SESSION_UUID"
echo "========================================="

# Wait for pod to be ready
echo ""
echo "1. WAITING FOR POD TO BE READY..."
kubectl wait --for=condition=Ready pod -l uuid=$SESSION_UUID -n $NAMESPACE --timeout=300s

POD_NAME=$(kubectl get pods -n $NAMESPACE -l uuid=$SESSION_UUID -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD_NAME"

# Test 1: Verify all 7 mounts exist
echo ""
echo "2. VERIFYING ENHANCED PERSISTENCE MOUNTS..."
kubectl describe pod $POD_NAME -n $NAMESPACE | grep -A 10 "Mounts:" | grep -E "(app|root|usr/local|var/lib/dpkg|opt|data/db|var/log)"

# Test 2: Check pod is running
echo ""
echo "3. CHECKING POD STATUS..."
kubectl get pod $POD_NAME -n $NAMESPACE

# Test 4: Verify PVC size
echo ""
echo "4. VERIFYING PVC SIZE (should be 15Gi)..."
kubectl get pvc pvc-$SESSION_UUID -n $NAMESPACE

# Test 5: Test file creation in persistent directories
echo ""
echo "5. TESTING FILE PERSISTENCE..."
kubectl exec $POD_NAME -n $NAMESPACE -- sh -c "echo 'test-app' > /app/test.txt && cat /app/test.txt"
kubectl exec $POD_NAME -n $NAMESPACE -- sh -c "echo 'test-root' > /root/test.txt && cat /root/test.txt"
kubectl exec $POD_NAME -n $NAMESPACE -- sh -c "echo 'test-opt' > /opt/test.txt && cat /opt/test.txt"

# Test 6: Test package installation persistence
echo ""
echo "6. TESTING PACKAGE INSTALLATION..."
kubectl exec $POD_NAME -n $NAMESPACE -- sh -c "which python3 && which node"

echo ""
echo "========================================="
echo "TEST COMPLETE"
echo "========================================="