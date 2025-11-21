# GCP Infrastructure with Terraform

Production-grade Google Cloud Platform infrastructure using Terraform for infrastructure-as-code and Google Kubernetes Engine for container orchestration.

## 🏗️ Architecture

This infrastructure includes:

- **Networking**: VPC with subnets and secondary IP ranges for GKE
- **GKE Cluster**: Choice between Standard (with spot/on-demand node pools) or Autopilot
- **Artifact Registry**: Docker container registry
- **Monitoring**: Alert policies and notification channels
- **Security**: Workload Identity for GKE pods and GitHub Actions federation
- **Load Balancer**: Optional HTTP(S) load balancer with SSL and CDN

## 📁 Repository Structure

```
.
├── environments/
│   └── dev/                    # Development environment configuration
│       ├── main.tf            # Environment-specific resources
│       ├── variables.tf       # Environment variables
│       ├── backend.tf         # Terraform state configuration
│       └── outputs.tf         # Environment outputs
├── modules/                    # Reusable Terraform modules
│   ├── network/               # VPC and subnet configuration
│   ├── gke/                   # GKE standard cluster
│   ├── gke-autopilot/         # GKE autopilot cluster
│   ├── gar/                   # Google Artifact Registry
│   ├── monitoring/            # Cloud Monitoring alerts
│   ├── security/              # Workload Identity for GKE
│   ├── wi-federation/         # Workload Identity Federation (GitHub Actions)
│   └── load-balancer/         # HTTP(S) Load Balancer
├── app/                       # Sample application code
├── k8s-manifests/             # Kubernetes manifests
├── .github/workflows/         # CI/CD pipelines
├── SECURITY.md                # Security documentation
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- Google Cloud Project with billing enabled

### Initial Setup

1. **Configure GCP credentials**:
   ```bash
   gcloud auth application-default login
   ```

2. **Set your project**:
   ```bash
   export TF_VAR_project_id="your-gcp-project-id"
   ```

3. **Initialize Terraform**:
   ```bash
   cd environments/dev
   terraform init
   ```

### Deploy Infrastructure

Using Makefile (recommended):
```bash
# Format and validate
make fmt
make validate

# Preview changes
make plan

# Apply changes (requires approval)
make apply
```

Or using Terraform directly:
```bash
cd environments/dev
terraform plan
terraform apply
```

## 📚 Module Documentation

Each module has comprehensive documentation:

- [Network Module](modules/network/README.md) - VPC and subnet with VPC flow logs
- [GKE Standard Module](modules/gke/README.md) - Standard GKE with spot/on-demand nodes
- [GKE Autopilot Module](modules/gke-autopilot/README.md) - Fully managed GKE
- [GAR Module](modules/gar/README.md) - Artifact Registry for containers
- [Monitoring Module](modules/monitoring/README.md) - Alert policies
- [Security Module](modules/security/README.md) - Workload Identity for GKE
- [WI Federation Module](modules/wi-federation/README.md) - GitHub Actions authentication
- [Load Balancer Module](modules/load-balancer/README.md) - HTTP(S) Load Balancer

## 💰 Cost Optimization

**Estimated Monthly Costs** (us-central1):

| Resource | Configuration | Estimated Cost |
|----------|--------------|----------------|
| GKE Standard (spot) | 2-20 nodes, e2-medium | ~$25-250/month |
| GKE Standard (on-demand) | 1-5 nodes, n2-standard-2 | ~$75-375/month |
| GKE Autopilot | Pay per pod | Variable, typically lower |
| VPC Network | Flow logs at 50% sampling | ~$5-20/month |
| Artifact Registry | Storage + data transfer | ~$5-50/month |
| Load Balancer | If enabled | ~$20-100/month |

**Total**: ~$125-575/month for Standard GKE setup

**Cost Saving Features**:
- 🔹 Spot instances (default) save ~70% vs on-demand
- 🔹 Autopilot option for pay-per-pod pricing
- 🔹 Autoscaling to match demand
- 🔹 Resource labels for cost tracking

## 🔒 Security

Security features implemented:
- ✅ VPC Flow Logs for network monitoring
- ✅ Workload Identity (no service account keys)
- ✅ Binary Authorization for deployment policies
- ✅ Shielded nodes with secure boot
- ✅ Network policies for pod isolation
- ✅ Private Google Access
- ✅ Auto-upgrade and auto-repair enabled

See [SECURITY.md](SECURITY.md) for detailed security documentation and optional hardening recommendations.

## 🔄 CI/CD Workflows

### Docker Workflow
Triggers on changes to `app/**`:
- Builds Docker image
- Scans for vulnerabilities (Trivy)
- Pushes to Artifact Registry

### Terraform Workflow
- **On Pull Request**: Runs `terraform plan`
- **On Main Push**: Runs `terraform apply` (requires approval)
- **Concurrency Control**: Prevents simultaneous runs

## 🛠️ Development

### Terraform Best Practices

This repository follows Terraform best practices:
- ✅ All variables have descriptions
- ✅ All outputs have descriptions
- ✅ Input validation where appropriate
- ✅ Consistent formatting (`terraform fmt`)
- ✅ Modular structure
- ✅ Version constraints specified

### Linting and Validation

```bash
# Run Terraform formatter
terraform fmt -recursive

# Validate configuration
cd environments/dev && terraform validate

# Run security scanner
tfsec modules/

# Run linter
tflint --recursive
```

## ⚙️ Configuration

### Storage Configuration

**Current Settings:**
- **Storage Type**: SSD (`premium-rwo`)
- **Storage Size**: 10GB per user session
- **Cost**: ~$1.70/month per active session

**To Modify Storage:**

1. **Change Storage Size** - Edit `session-manager/app.py` line 133:
   ```python
   requests={"storage": "20Gi"}  # Change from 10Gi to desired size
   ```

2. **Change Storage Type** - Edit `session-manager/app.py` line 131:
   ```python
   storage_class_name="standard-rwo"  # HDD (~$0.40/month per 10GB)
   storage_class_name="premium-rwo"   # SSD (~$1.70/month per 10GB)
   ```

3. **Rebuild and Deploy:**
   ```bash
   cd session-manager
   docker build --platform linux/amd64 -t us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/session-manager:latest .
   docker push us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/session-manager:latest
   kubectl rollout restart deployment/session-manager -n fresh-system
   ```

### Resource Configuration

**Pod Resources** - Edit `session-manager/app.py` lines 67-70:
```python
resources=client.V1ResourceRequirements(
    requests={"memory": "512Mi", "cpu": "500m"},  # Increase for more power
    limits={"memory": "1Gi", "cpu": "1000m"}
)
```

### Persistent Paths Configuration

**Currently Active Paths:**
- `/app` - Application code and projects
- `/root` - User home directory and configs
- `/data/db` - Database and data files

**To Enable Additional Paths** - Uncomment in `session-manager/app.py` lines 85-95:
```python
# Uncomment these when using compatible Docker image:
client.V1VolumeMount(
    name="user-data",
    mount_path="/etc/supervisor",
    sub_path="etc/supervisor"
),
client.V1VolumeMount(
    name="user-data",
    mount_path="/var/log",
    sub_path="var/log"
)
```

## 🔧 Troubleshooting

### State Lock Issues

If Terraform state is locked:
```bash
# Using Makefile
make unlock LOCK_ID=<lock-id-from-error>

# Or directly
cd environments/dev
terraform force-unlock <lock-id>
```

**Prevention**: State locks are automatically prevented by:
- GitHub Actions concurrency control
- Makefile commands with proper cleanup

### Common Issues

**Issue**: `terraform init` fails
- **Solution**: Check GCS bucket exists and you have access

**Issue**: GKE cluster creation timeout
- **Solution**: Increase timeout or check quotas in GCP

**Issue**: DNS/SSL certificate not provisioning
- **Solution**: Wait up to 24 hours for DNS propagation and certificate provisioning

## 📖 Additional Resources

- [GCP Terraform Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [GKE Hardening Guide](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run linting and validation
5. Submit a pull request
# Test non-tf push
# Clean deploy
# Fresh deploy
