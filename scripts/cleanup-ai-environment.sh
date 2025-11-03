#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <UUID>"
    exit 1
fi

UUID=$1
echo "Cleaning up AI environment: $UUID"

kubectl delete deployment agent-env-$UUID
kubectl delete service agent-service-$UUID
kubectl delete ingress agent-ingress-$UUID
kubectl delete pvc app-pvc-$UUID data-pvc-$UUID log-pvc-$UUID

echo "✅ Cleanup completed: $UUID"
