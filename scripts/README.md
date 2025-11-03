# AI Platform Deployment Scripts

## Quick Start

### Deploy New AI Environment
```bash
./scripts/deploy-ai-environment.sh
```

### Cleanup Environment
```bash
./scripts/cleanup-ai-environment.sh <UUID>
```

## Prerequisites
- kubectl configured with GKE cluster
- Ingress controller installed
- DNS configured for *.preview.yourdomain.com

## What Gets Created
- 3 PVCs (app, data, logs) - 25Gi total
- Deployment with 1 CPU, 2Gi RAM
- Service exposing ports 8080, 3000, 8001
- Ingress with unique subdomain
