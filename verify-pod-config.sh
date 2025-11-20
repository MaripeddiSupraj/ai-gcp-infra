#!/bin/bash

echo "🔍 Pod Configuration Verification"
echo "================================="

if [ -z "$1" ]; then
    echo "Usage: $0 <session-uuid>"
    echo "Example: $0 abc12345"
    exit 1
fi

SESSION_UUID=$1

echo "📝 Checking deployment for session: $SESSION_UUID"

# Check if deployment exists
kubectl get deployment -n fresh-system user-${SESSION_UUID} > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Deployment user-${SESSION_UUID} not found"
    exit 1
fi

echo "✅ Deployment exists"

# Check PVC
kubectl get pvc -n fresh-system pvc-${SESSION_UUID} > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ PVC pvc-${SESSION_UUID} not found"
    exit 1
fi

echo "✅ PVC exists"

# Get pod name
POD_NAME=$(kubectl get pod -n fresh-system -l uuid=${SESSION_UUID} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "⚠️ No pod running (might be sleeping)"
else
    echo "✅ Pod running: $POD_NAME"
    
    echo ""
    echo "📋 Volume Mounts Configuration:"
    kubectl get pod -n fresh-system $POD_NAME -o jsonpath='{.spec.containers[0].volumeMounts}' | jq '.'
    
    echo ""
    echo "📋 Volume Configuration:"
    kubectl get pod -n fresh-system $POD_NAME -o jsonpath='{.spec.volumes}' | jq '.'
    
    echo ""
    echo "📋 Expected Mount Points:"
    echo "  /app           ← PVC:app"
    echo "  /root          ← PVC:root"  
    echo "  /etc/supervisor ← PVC:etc/supervisor"
    echo "  /var/log       ← PVC:var/log"
    echo "  /data/db       ← PVC:data/db"
fi

echo ""
echo "📋 PVC Details:"
kubectl describe pvc -n fresh-system pvc-${SESSION_UUID}