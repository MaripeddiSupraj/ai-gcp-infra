# Kubernetes AI Development Platform - Complete Infrastructure Guide

## Overview
This guide provides a complete end-to-end workflow to recreate an Emergent-like AI development platform on Google Kubernetes Engine (GKE). The infrastructure supports dynamic AI coding environments with automatic URL routing and isolated container workloads.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Internet Layer                        │
│  https://vscode-{UUID}.preview.yourdomain.com/         │
└─────────────────────────────────────────────────────────┘
                            ⬇
┌─────────────────────────────────────────────────────────┐
│              Google Cloud Load Balancer                 │
│                 External IP: X.X.X.X                   │
└─────────────────────────────────────────────────────────┘
                            ⬇
┌─────────────────────────────────────────────────────────┐
│               Kubernetes Ingress Controller              │
│          Routes {UUID} → Pod agent-env-{UUID}          │
└─────────────────────────────────────────────────────────┘
                            ⬇
┌─────────────────────────────────────────────────────────┐
│                  GKE Cluster Nodes                      │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ │
│  │ us-central1-a │ │ us-central1-b │ │ us-central1-c │ │
│  │   2-3 nodes   │ │   2-3 nodes   │ │   2-4 nodes   │ │
│  └───────────────┘ └───────────────┘ └───────────────┘ │
└─────────────────────────────────────────────────────────┘
                            ⬇
┌─────────────────────────────────────────────────────────┐
│              Individual Pod Architecture                 │
│  ┌─────────────────────────────────────────────────────┐│
│  │  Pod: agent-env-{UUID}                             ││
│  │  Internal IP: 10.219.x.x                           ││
│  │                                                     ││
│  │  ┌─────────────────────────────────────────────────┐││
│  │  │          Nginx Proxy (Port 1111)               │││
│  │  │    Routes traffic to internal services          │││
│  │  └─────────────────────────────────────────────────┘││
│  │                         ⬇                          ││
│  │  ┌─────────────────────────────────────────────────┐││
│  │  │VSCode:8080│Frontend:3000│Backend:8001│Tools:8010│││
│  │  │           │MongoDB:27017│                       │││
│  │  └─────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

## Infrastructure Specifications

### Cluster Configuration
- **Platform:** Google Kubernetes Engine (GKE)
- **Region:** us-central1 (multi-zone: a,b,c)
- **Node Type:** n1-standard-8 (8 vCPU, 32GB RAM)
- **Storage:** 120GB SSD + 4x Local SSD per node
- **Network:** Custom VPC with Pod CIDR 10.219.0.0/16
- **Container Runtime:** Containerd with Container-Optimized OS

### Resource Allocation per Pod
- **CPU Limit:** 1 core (from 8 available)
- **Memory Limit:** 2GB (from 32GB available) 
- **Storage:** 10GB dedicated volume
- **Network:** Private IP in 10.219.x.x range

### Pod Capacity
- **Per Node:** 8 AI coding environments (resource-constrained)
- **Cluster Total:** ~64 high-resource AI pods
- **Mixed Workloads:** ~200-500 pods (with smaller containers)
- **Kubernetes Limit:** 880 pods maximum

## Prerequisites

### Required Tools
- Google Cloud SDK (`gcloud`)
- Kubernetes CLI (`kubectl`)
- Docker
- Terraform (optional, for infrastructure as code)
- Helm (for package management)

### GCP Services to Enable
- Kubernetes Engine API
- Compute Engine API 
- Container Registry API
- Artifact Registry API
- Cloud Logging API
- Cloud Monitoring API

## Phase 1: Project and Network Setup

### 1.1 Project Configuration
```bash
# Set project variables
export PROJECT_ID="your-ai-platform-project"
export REGION="us-central1"
export ZONE="us-central1-c"
export CLUSTER_NAME="ai-development-cluster"
export NETWORK_NAME="ai-platform-vpc"
export SUBNET_NAME="ai-platform-subnet"

# Authenticate and configure project
gcloud auth login
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE
```

### 1.2 Enable Required APIs
```bash
# Enable all necessary GCP services
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable networkmanagement.googleapis.com
```

### 1.3 Create Custom VPC Network
```bash
# Create custom VPC network
gcloud compute networks create $NETWORK_NAME \
    --subnet-mode=custom \
    --bgp-routing-mode=regional

# Create subnet with Pod CIDR matching Emergent's setup
gcloud compute networks subnets create $SUBNET_NAME \
    --network=$NETWORK_NAME \
    --range=10.219.0.0/16 \
    --region=$REGION \
    --secondary-range=pods=10.219.0.0/16 \
    --secondary-range=services=10.220.0.0/16

# Create firewall rules
gcloud compute firewall-rules create ai-platform-allow-internal \
    --network=$NETWORK_NAME \
    --allow=tcp,udp,icmp \
    --source-ranges=10.219.0.0/16,10.220.0.0/16

gcloud compute firewall-rules create ai-platform-allow-ssh \
    --network=$NETWORK_NAME \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0
```

## Phase 2: Container Registry Setup

### 2.1 Create Artifact Registry
```bash
# Create Docker repository
gcloud artifacts repositories create ai-images \
    --repository-format=docker \
    --location=$REGION \
    --description="AI development environment images"

# Configure Docker authentication
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

### 2.2 Build and Push Base Images
```bash
# Create AI development environment Dockerfile
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nginx \
    supervisor \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    mongodb \
    && rm -rf /var/lib/apt/lists/*

# Install Yarn
RUN npm install -g yarn

# Install VSCode Server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Create application directories
RUN mkdir -p /app /data/db /var/log/supervisor

# Configure supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx-code-server.conf

# Expose ports
EXPOSE 1111 3000 8001 8010 8080 27017

# Set working directory
WORKDIR /app

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
EOF

# Build and push image
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/ai-images/ai-environment:v1.0 .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/ai-images/ai-environment:v1.0
```

## Phase 3: GKE Cluster Creation

### 3.1 Create Advanced GKE Cluster
```bash
# Create GKE cluster with exact Emergent specifications
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --network=$NETWORK_NAME \
    --subnetwork=$SUBNET_NAME \
    --cluster-secondary-range-name=pods \
    --services-secondary-range-name=services \
    --machine-type=n1-standard-8 \
    --num-nodes=2 \
    --min-nodes=1 \
    --max-nodes=10 \
    --enable-autoscaling \
    --disk-size=120GB \
    --disk-type=pd-ssd \
    --local-ssd-count=4 \
    --image-type=COS_CONTAINERD \
    --enable-autorepair \
    --enable-autoupgrade \
    --enable-network-policy \
    --enable-ip-alias \
    --enable-shielded-nodes \
    --shielded-secure-boot \
    --shielded-integrity-monitoring \
    --enable-cloud-logging \
    --enable-cloud-monitoring \
    --workload-pool=${PROJECT_ID}.svc.id.goog
```

### 3.2 Create Specialized Node Pool for AI Workloads
```bash
# Create AI-optimized node pool
gcloud container node-pools create ai-workload-pool \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --num-nodes=2 \
    --min-nodes=0 \
    --max-nodes=20 \
    --enable-autoscaling \
    --local-ssd-count=4 \
    --disk-size=100GB \
    --disk-type=pd-ssd \
    --node-taints=workload-type=ai-intensive:NoSchedule \
    --node-labels=workload-type=ai-intensive,storage-type=nvme \
    --preemptible=false
```

### 3.3 Get Cluster Credentials
```bash
# Configure kubectl
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# Verify cluster
kubectl get nodes -o wide
kubectl cluster-info
```

## Phase 4: Storage Configuration

### 4.1 Create Storage Classes
```bash
# Apply high-performance storage class
kubectl apply -f - << 'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nvme-ssd
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  zones: us-central1-a,us-central1-b,us-central1-c
  replication-type: regional-pd
allowVolumeExpansion: true
reclaimPolicy: Retain
EOF
```

### 4.2 Create Local SSD Storage Class
```bash
# Local SSD storage for high-performance workloads
kubectl apply -f - << 'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-nvme
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF
```

## Phase 5: Ingress Controller Setup

### 5.1 Install Nginx Ingress Controller
```bash
# Install via Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.type=LoadBalancer \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.config.use-proxy-protocol="true" \
    --set controller.service.annotations."cloud\.google\.com/load-balancer-type"="External"

# Wait for external IP assignment
echo "Waiting for external IP..."
kubectl get svc -n ingress-nginx ingress-nginx-controller --watch
```

### 5.2 Configure DNS and SSL
```bash
# Get the external IP
export INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"

# Configure DNS (you'll need to set this up in your DNS provider)
echo "Configure these DNS records:"
echo "*.preview.yourdomain.com A $INGRESS_IP"
echo "vscode-*.preview.yourdomain.com A $INGRESS_IP"
```

## Phase 6: Dynamic Pod Deployment System

### 6.1 Create Pod Template
```bash
# Create configurable pod template
cat > ai-pod-template.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-env-UUID_PLACEHOLDER
  labels:
    app: ai-environment
    uuid: UUID_PLACEHOLDER
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ai-environment
      uuid: UUID_PLACEHOLDER
  template:
    metadata:
      labels:
        app: ai-environment
        uuid: UUID_PLACEHOLDER
    spec:
      tolerations:
      - key: "workload-type"
        operator: "Equal"
        value: "ai-intensive"
        effect: "NoSchedule"
      nodeSelector:
        workload-type: ai-intensive
      containers:
      - name: ai-environment
        image: REGION_PLACEHOLDER-docker.pkg.dev/PROJECT_PLACEHOLDER/ai-images/ai-environment:v1.0
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        ports:
        - containerPort: 1111
          name: nginx-proxy
        - containerPort: 3000
          name: frontend
        - containerPort: 8001
          name: backend
        - containerPort: 8010
          name: agent-tools
        - containerPort: 8080
          name: vscode
        - containerPort: 27017
          name: mongodb
        volumeMounts:
        - name: app-storage
          mountPath: /app
        - name: data-storage
          mountPath: /data/db
        - name: log-storage
          mountPath: /var/log
        env:
        - name: POD_UUID
          value: UUID_PLACEHOLDER
        - name: WORKSPACE_URL
          value: "https://vscode-UUID_PLACEHOLDER.preview.yourdomain.com/"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: false
          capabilities:
            drop:
            - ALL
      volumes:
      - name: app-storage
        persistentVolumeClaim:
          claimName: app-pvc-UUID_PLACEHOLDER
      - name: data-storage
        persistentVolumeClaim:
          claimName: data-pvc-UUID_PLACEHOLDER
      - name: log-storage
        persistentVolumeClaim:
          claimName: log-pvc-UUID_PLACEHOLDER
---
apiVersion: v1
kind: Service
metadata:
  name: agent-service-UUID_PLACEHOLDER
  labels:
    app: ai-environment
    uuid: UUID_PLACEHOLDER
spec:
  selector:
    app: ai-environment
    uuid: UUID_PLACEHOLDER
  ports:
  - port: 1111
    targetPort: 1111
    name: nginx-proxy
  - port: 3000
    targetPort: 3000
    name: frontend
  - port: 8001
    targetPort: 8001
    name: backend
  - port: 8080
    targetPort: 8080
    name: vscode
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: agent-ingress-UUID_PLACEHOLDER
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
spec:
  rules:
  - host: vscode-UUID_PLACEHOLDER.preview.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: agent-service-UUID_PLACEHOLDER
            port:
              number: 8080
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: agent-service-UUID_PLACEHOLDER
            port:
              number: 8001
EOF
```

### 6.2 Create PVC Template
```bash
# Create persistent volume claims template
cat > pvc-template.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc-UUID_PLACEHOLDER
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nvme-ssd
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc-UUID_PLACEHOLDER
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nvme-ssd
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: log-pvc-UUID_PLACEHOLDER
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nvme-ssd
  resources:
    requests:
      storage: 5Gi
EOF
```

## Phase 7: Monitoring and Auto-scaling

### 7.1 Install Monitoring Stack
```bash
# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --set prometheus.service.type=LoadBalancer \
    --set grafana.service.type=LoadBalancer
```

### 7.2 Configure Auto-scaling
```bash
# Horizontal Pod Autoscaler template
cat > hpa-template.yaml << 'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ai-workload-hpa-UUID_PLACEHOLDER
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: agent-env-UUID_PLACEHOLDER
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF
```

## Phase 8: Security and Network Policies

### 8.1 Create Network Policies
```bash
# Network isolation policy
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ai-workload-isolation
spec:
  podSelector:
    matchLabels:
      app: ai-environment
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 3000
    - protocol: TCP
      port: 8001
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF
```

## Phase 9: Deployment Scripts

### 9.1 Create Deployment Script
```bash
# Create dynamic deployment script
cat > deploy-ai-environment.sh << 'EOF'
#!/bin/bash

# Generate UUID for new environment
UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
echo "Creating AI environment with UUID: $UUID"

# Replace placeholders in templates
sed "s/UUID_PLACEHOLDER/$UUID/g; s/REGION_PLACEHOLDER/$REGION/g; s/PROJECT_PLACEHOLDER/$PROJECT_ID/g" pvc-template.yaml > pvc-$UUID.yaml
sed "s/UUID_PLACEHOLDER/$UUID/g; s/REGION_PLACEHOLDER/$REGION/g; s/PROJECT_PLACEHOLDER/$PROJECT_ID/g" ai-pod-template.yaml > ai-pod-$UUID.yaml
sed "s/UUID_PLACEHOLDER/$UUID/g" hpa-template.yaml > hpa-$UUID.yaml

# Deploy resources
echo "Deploying PVCs..."
kubectl apply -f pvc-$UUID.yaml

echo "Waiting for PVCs to be bound..."
kubectl wait --for=condition=Bound pvc/app-pvc-$UUID --timeout=300s
kubectl wait --for=condition=Bound pvc/data-pvc-$UUID --timeout=300s
kubectl wait --for=condition=Bound pvc/log-pvc-$UUID --timeout=300s

echo "Deploying AI environment..."
kubectl apply -f ai-pod-$UUID.yaml

echo "Configuring auto-scaling..."
kubectl apply -f hpa-$UUID.yaml

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/agent-env-$UUID

echo "Getting service status..."
kubectl get pods,svc,ingress -l uuid=$UUID

echo "AI environment deployed successfully!"
echo "Access URL: https://vscode-$UUID.preview.yourdomain.com/"
echo "UUID: $UUID"

# Cleanup temp files
rm pvc-$UUID.yaml ai-pod-$UUID.yaml hpa-$UUID.yaml
EOF

chmod +x deploy-ai-environment.sh
```

### 9.2 Create Cleanup Script
```bash
# Create cleanup script
cat > cleanup-ai-environment.sh << 'EOF'
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <UUID>"
    echo "Example: $0 4da3eb69-d94a-46c3-bfc8-7f0b21a98ccb"
    exit 1
fi

UUID=$1

echo "Cleaning up AI environment: $UUID"

# Delete resources
kubectl delete deployment agent-env-$UUID
kubectl delete service agent-service-$UUID
kubectl delete ingress agent-ingress-$UUID
kubectl delete hpa ai-workload-hpa-$UUID
kubectl delete pvc app-pvc-$UUID data-pvc-$UUID log-pvc-$UUID

echo "Cleanup completed for UUID: $UUID"
EOF

chmod +x cleanup-ai-environment.sh
```

## Phase 10: Verification and Testing

### 10.1 Deploy Test Environment
```bash
# Deploy a test AI environment
./deploy-ai-environment.sh

# Monitor deployment
watch kubectl get pods,svc,ingress
```

### 10.2 Verify Functionality
```bash
# Check cluster health
kubectl get nodes -o wide
kubectl top nodes
kubectl get pods --all-namespaces

# Test networking
kubectl exec -it deployment/agent-env-<UUID> -- /bin/bash
# Inside pod:
curl localhost:8080  # VSCode
curl localhost:3000  # Frontend
curl localhost:8001/health  # Backend
curl localhost:8010/health  # Agent Tools
```

## Resource Management

### Current Capacity
- **Nodes:** 6-10 nodes (2 per zone)
- **Total CPU:** 48-80 cores
- **Total Memory:** 192-320 GB
- **AI Environments:** 64 maximum (1 CPU, 2GB each)
- **Storage:** 10GB per environment + system storage

### Cost Estimation (Monthly)
- **GKE Cluster:** $72
- **Compute (n1-standard-8):** $600-1000
- **Storage (SSD):** $200-400
- **Load Balancers:** $20-40
- **Network Egress:** $50-100
- **Total:** ~$1,000-1,600/month

## Maintenance Commands

### Cluster Management
```bash
# Scale node pool
gcloud container clusters resize $CLUSTER_NAME --num-nodes 3 --zone $ZONE

# Upgrade cluster
gcloud container clusters upgrade $CLUSTER_NAME --zone $ZONE

# Backup
kubectl get all -o yaml > cluster-backup.yaml
```

### Monitoring
```bash
# Resource usage
kubectl top nodes
kubectl top pods

# Logs
kubectl logs -f deployment/agent-env-<UUID>

# Events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Troubleshooting
```bash
# Debug pod issues
kubectl describe pod <pod-name>
kubectl exec -it <pod-name> -- /bin/bash

# Network debugging
kubectl run debug-pod --image=nicolaka/netshoot -it --rm

# Check ingress
kubectl describe ingress agent-ingress-<UUID>
```

## Security Best Practices

1. **Enable Workload Identity**
2. **Use Network Policies** for pod isolation
3. **Enable Pod Security Policies**
4. **Regular security updates** for node images
5. **Monitor resource usage** and set limits
6. **Use private clusters** for production
7. **Implement proper RBAC** controls
8. **Enable audit logging**

## Next Steps

1. **SSL/TLS Configuration** - Set up proper certificates
2. **CI/CD Integration** - Automate deployments
3. **Backup Strategy** - Implement data backup
4. **Disaster Recovery** - Multi-region setup
5. **Performance Optimization** - Fine-tune resources
6. **Security Hardening** - Additional security measures

---

*This infrastructure provides a production-ready foundation for AI development platforms similar to Emergent's architecture.*