# Project Handover Guide

## Quick Start (5 Minutes)

### Prerequisites
- GCP Project with billing enabled
- GitHub repository access
- GCP Service Account key (JSON)

### Setup Steps

1. **Configure GitHub Secrets**
   - Go to: Settings → Secrets and variables → Actions
   - Add secret: `GCP_SA_KEY` (paste service account JSON)

2. **Update Configuration**
   - Edit `terraform.tfvars` with your values:
     ```hcl
     project_id    = "your-project-id"
     region        = "us-central1"
     alert_email   = "your-email@example.com"
     github_repository = "your-org/your-repo"
     ```

3. **Deploy Everything**
   - Go to: Actions → "Complete CI/CD Pipeline"
   - Click "Run workflow"
   - Check all boxes
   - Click "Run workflow"
   - Approve when prompted

## What This Infrastructure Provides

### GCP Resources Created
- ✅ VPC Network with subnets
- ✅ GKE Cluster (Kubernetes)
  - On-demand node pool (1-5 nodes)
  - Spot node pool (1-10 nodes, 70% cost savings)
  - Cluster autoscaling
  - VPA (Vertical Pod Autoscaling)
- ✅ Artifact Registry (Docker images)
- ✅ Cloud Monitoring with alerts
- ✅ Workload Identity (secure access)

### Kubernetes Resources
- ✅ Priority classes (high/low)
- ✅ Pod Disruption Budgets
- ✅ Network policies (zero-trust)
- ✅ Pod Security Standards
- ✅ HPA (Horizontal Pod Autoscaling)
- ✅ Service accounts with Workload Identity

### CI/CD Pipelines
- ✅ Terraform: Validate → Plan → Apply
- ✅ Docker: Build → Scan → Push
- ✅ K8s: Deploy → Health Check → Rollback
- ✅ Security: Weekly scans
- ✅ Drift: Daily detection

## Daily Operations

### Deploy New Code
1. Push code to `app/` folder
2. Automatic: Build → Push → Deploy

### Update Infrastructure
1. Edit `.tf` files
2. Push to main
3. Approve in Actions tab

### Update K8s Manifests
1. Edit `k8s-manifests/` files
2. Push to main
3. Auto-deploys

### Manual Deployment
- Actions → "Complete CI/CD Pipeline" → Run workflow

## Monitoring

### Check Cluster Status
```bash
gcloud container clusters get-credentials primary-cluster --region us-central1
kubectl get pods --all-namespaces
kubectl get nodes
```

### View Logs
```bash
kubectl logs -l app=myapp
kubectl logs -l app=myapp-critical -n prod
```

### Check Alerts
- GCP Console → Monitoring → Alerting
- Email notifications configured

## Cost Optimization

- **Spot nodes**: ~70% savings for non-critical workloads
- **Cluster autoscaling**: Scales down when idle
- **VPA**: Right-sizes pod resources
- **Current setup**: ~$100-150/month

## Troubleshooting

### Workflow Failed
1. Check Actions tab for error
2. Review logs
3. Re-run workflow

### Pod Not Starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Terraform Drift
- Check GitHub Issues for drift alerts
- Run: `terraform plan` to see changes

## Security

### Secrets
- Never commit `terraform.tfvars`
- Never commit service account keys
- Use GitHub Secrets for sensitive data

### Access
- Workload Identity (no keys in pods)
- Network policies (default deny)
- Pod Security Standards enforced

## File Structure

```
.
├── main.tf                    # Root Terraform config
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars          # Your configuration (gitignored)
├── modules/                   # Terraform modules
│   ├── network/              # VPC
│   ├── gke/                  # GKE cluster
│   ├── gar/                  # Artifact Registry
│   ├── monitoring/           # Alerts
│   └── security/             # Workload Identity
├── k8s-manifests/            # Kubernetes resources
│   ├── deployment.yaml       # Spot nodes
│   ├── deployment-critical.yaml  # On-demand nodes
│   ├── service.yaml
│   ├── hpa.yaml
│   └── ...
├── app/                      # Application code
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
└── .github/workflows/        # CI/CD pipelines
    ├── terraform-apply.yml
    ├── docker-build-push.yml
    ├── k8s-deploy.yml
    └── complete-pipeline.yml
```

## Important URLs

- **GitHub Actions**: https://github.com/YOUR_ORG/YOUR_REPO/actions
- **GCP Console**: https://console.cloud.google.com
- **GKE Clusters**: https://console.cloud.google.com/kubernetes/list
- **Artifact Registry**: https://console.cloud.google.com/artifacts

## Support Contacts

- **Infrastructure**: [Your Name/Email]
- **GCP Support**: https://cloud.google.com/support
- **Documentation**: See README.md, WORKFLOWS.md, SECURITY.md

## Handover Checklist

- [ ] GitHub Secrets configured (`GCP_SA_KEY`)
- [ ] `terraform.tfvars` updated with correct values
- [ ] Service account has required permissions
- [ ] Test deployment successful
- [ ] Monitoring alerts working
- [ ] Team has access to GitHub repo
- [ ] Team has access to GCP project
- [ ] Documentation reviewed
- [ ] Emergency contacts shared

## Emergency Procedures

### Infrastructure Down
1. Check GCP Console for issues
2. Check GitHub Actions for failed workflows
3. Review monitoring alerts
4. Contact GCP support if needed

### Rollback Deployment
```bash
kubectl rollout undo deployment/app
kubectl rollout undo deployment/app-critical -n prod
```

### Destroy Everything (CAUTION!)
```bash
terraform destroy
```

## Next Steps After Handover

1. **Week 1**: Monitor daily, ensure stability
2. **Week 2**: Team takes over daily operations
3. **Month 1**: Review costs and optimize
4. **Ongoing**: Weekly security scans, monthly reviews

## Questions?

Refer to:
- `README.md` - Overview and features
- `WORKFLOWS.md` - Detailed workflow documentation
- `SECURITY.md` - Security policies
- GitHub Issues - For problems and questions

---

**Last Updated**: $(date)
**Version**: 1.0
**Status**: Production Ready ✅
