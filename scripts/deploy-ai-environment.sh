#!/bin/bash
set -e

UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
echo "Creating AI environment: $UUID"

sed "s/UUID_PLACEHOLDER/$UUID/g" k8s-templates/pvc-template.yaml | kubectl apply -f -
kubectl wait --for=condition=Bound pvc/app-pvc-$UUID --timeout=300s

sed "s/UUID_PLACEHOLDER/$UUID/g" k8s-templates/ai-pod-template.yaml | kubectl apply -f -
kubectl wait --for=condition=available --timeout=600s deployment/agent-env-$UUID

echo "✅ Deployed: https://vscode-$UUID.preview.yourdomain.com/"
echo "UUID: $UUID"
