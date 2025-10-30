# ai-gcp-infra

Production-grade Terraform infrastructure for GCP with enterprise-level features.

## Features

### Infrastructure
- **VPC Network**: Custom VPC with subnet and secondary IP ranges for GKE
- **GKE Cluster**: Google Kubernetes Engine with:
  - Cluster Autoscaling (2-20 CPUs, 4-64GB RAM)
  - Vertical Pod Autoscaling (VPA)
  - Managed Prometheus monitoring
  - Security posture management
  - Workload Identity enabled
- **Node Pools**:
  - On-demand nodes (1-5 nodes) for critical workloads
  - Spot nodes (1-10 nodes) for cost-effective workloads
- **Artifact Registry**: Docker repository for container images
- **Cloud Monitoring**: Alerts for pod restarts, CPU usage, spot preemptions
- **Workload Identity**: Secure GCP service access without keys

### Kubernetes Resources
- **Priority Classes**: High/low priority for workload scheduling
- **Pod Disruption Budgets**: High availability during disruptions
- **Network Policies**: Zero-trust network security
- **Pod Security Standards**: Baseline/restricted security enforcement
- **HPA**: Horizontal Pod Autoscaling
- **VPA**: Vertical Pod Autoscaling
- **Ingress**: GCE ingress with managed SSL certificates

### CI/CD
- **Terraform workflows**: Check, plan, apply with validation
- **Docker workflow**: Build, scan (Trivy), SBOM generation, push
- **K8s deployment**: Automated deployment with health checks and rollback
- **Security scanning**: Weekly Kubesec, Checkov, tfsec scans

## Structure

```
.
├── modules/
│   ├── network/       # VPC and subnet
│   ├── gke/           # GKE cluster with autoscaling
│   ├── gar/           # Artifact Registry
│   ├── monitoring/    # Cloud Monitoring alerts
│   └── security/      # Workload Identity
├── k8s-manifests/
│   ├── network-policies/  # Network security
│   ├── security/          # Pod security, service accounts
│   ├── monitoring/        # VPA resources
│   ├── ingress/           # Ingress with SSL
│   ├── deployment.yaml    # Spot node deployment
│   ├── deployment-critical.yaml  # On-demand deployment
│   ├── hpa.yaml
│   ├── service.yaml
│   ├── priority-classes.yaml
│   └── pod-disruption-budget.yaml
├── app/               # Application code
└── .github/workflows/ # CI/CD pipelines
```

## Prerequisites

- GCP Project with billing enabled
- Terraform >= 1.0
- kubectl
- Required GCP APIs:
  - Compute Engine API
  - Kubernetes Engine API
  - Artifact Registry API
  - Cloud Monitoring API

## Setup

1. Copy and edit variables:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Configure `terraform.tfvars`:
```hcl
project_id               = "your-project-id"
region                   = "us-central1"
alert_email              = "alerts@example.com"
workload_identity_roles  = ["roles/storage.objectViewer"]
```

3. Deploy infrastructure:
```bash
terraform init
terraform plan
terraform apply
```

4. Configure kubectl:
```bash
gcloud container clusters get-credentials primary-cluster --region us-central1
```

5. Deploy Kubernetes resources:
```bash
kubectl apply -f k8s-manifests/namespace-*.yaml
kubectl apply -f k8s-manifests/priority-classes.yaml
kubectl apply -f k8s-manifests/security/
kubectl apply -f k8s-manifests/network-policies/
kubectl apply -f k8s-manifests/
```

## Cost Optimization

- **Spot nodes**: ~70% cost savings for non-critical workloads
- **Cluster autoscaling**: Scale down during low usage
- **VPA**: Right-size pod resources automatically
- **Preemptible workloads**: Use low-priority class for batch jobs

## Security Features

- Network policies (default deny)
- Pod Security Standards (baseline/restricted)
- Workload Identity (no service account keys)
- Security context (non-root, read-only filesystem)
- Binary authorization
- Shielded GKE nodes
- Regular security scans

## Monitoring & Alerts

Configured alerts:
- High pod restart rate (>5 in 5 min)
- High node CPU usage (>80%)
- Spot instance preemptions

## GitHub Actions

### Required Secrets
- `GCP_SA_KEY`: Service account key JSON

### Required Variables
- `GCP_PROJECT_ID`: GCP project ID
- `GCP_REGION`: GCP region
- `GAR_REPO_ID`: Artifact Registry repo ID
- `GKE_CLUSTER_NAME`: GKE cluster name

## Production Checklist

- [ ] Update alert email in terraform.tfvars
- [ ] Configure custom domain in ingress.yaml
- [ ] Set up Cloud Armor for DDoS protection
- [ ] Enable GKE backup for disaster recovery
- [ ] Configure log retention policies
- [ ] Set up multi-region deployment
- [ ] Review and adjust resource limits
- [ ] Configure backup strategy
- [ ] Set up monitoring dashboards
- [ ] Document runbooks for incidents

## License

MIT
