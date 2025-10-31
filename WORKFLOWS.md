# GitHub Actions Workflows Guide

## Overview

This repository uses GitHub Actions for complete CI/CD automation.

## Workflows

### 1. **Terraform Apply** (`terraform-apply.yml`)
**Triggers:**
- Push to main (when `.tf` files change)
- Manual trigger

**What it does:**
1. Format check & validation
2. TFLint security scan
3. Generate Terraform plan
4. **Manual approval required** (production environment)
5. Apply infrastructure changes

**Required Secrets:**
- `GCP_SA_KEY`: Service account JSON key

---

### 2. **Docker Build and Push** (`docker-build-push.yml`)
**Triggers:**
- Push to main (when `app/**` changes)
- Pull request
- Called by complete pipeline

**What it does:**
1. Build Docker image
2. Run Trivy security scan
3. Generate SBOM
4. Push to Artifact Registry
5. **Auto-trigger K8s deployment**

**Required Secrets:**
- `GCP_SA_KEY`: Service account JSON key

---

### 3. **Deploy to GKE** (`k8s-deploy.yml`)
**Triggers:**
- Push to main (when `k8s-manifests/**` change)
- Manual trigger
- Called by Docker workflow
- Called by complete pipeline

**What it does:**
1. Validate manifests
2. Deploy security & network policies
3. Deploy application
4. Update container image
5. Health checks
6. **Auto-rollback on failure**

**Required Secrets:**
- `GCP_SA_KEY`: Service account JSON key

**Configuration:**
- Cluster: `primary-cluster`
- Region: `us-central1`
- Project: `hyperbola-476507`

---

### 4. **Complete Pipeline** (`complete-pipeline.yml`) ⭐
**Triggers:**
- Manual trigger only

**What it does:**
Orchestrates the entire deployment:
1. (Optional) Deploy infrastructure
2. Build & push Docker image
3. Deploy to Kubernetes

**Use this for:**
- Full end-to-end deployment
- Testing complete pipeline
- Production releases

---

### 5. **Security Scan** (`security-scan.yml`)
**Triggers:**
- Weekly (Sunday at midnight)
- Manual trigger

**What it does:**
1. Kubesec scan (K8s manifests)
2. Checkov scan (K8s manifests)
3. tfsec scan (Terraform)
4. Upload results to GitHub Security

---

### 6. **Terraform Drift Detection** (`terraform-drift.yml`)
**Triggers:**
- Daily (weekdays at 8 AM UTC)
- Manual trigger

**What it does:**
1. Run terraform plan
2. Detect manual changes
3. Create GitHub issue if drift found

---

### 7. **Terraform Check** (`terraform-check.yml`)
**Triggers:**
- Pull request (when `.tf` files change)
- Push to main

**What it does:**
1. Format check
2. Validation
3. TFLint

---

### 8. **Terraform Plan** (`terraform-plan.yml`)
**Triggers:**
- Pull request (when `.tf` files change)

**What it does:**
1. Run checks
2. Generate plan
3. Comment plan on PR

---

## Automated Flow

### When you push code to `app/`:
```
1. Docker Build → 2. Push to Registry → 3. Deploy to GKE
```

### When you push Terraform changes:
```
1. Check → 2. Plan → 3. Manual Approval → 4. Apply
```

### When you push K8s manifests:
```
1. Validate → 2. Deploy → 3. Health Check → 4. Rollback (if failed)
```

---

## Manual Deployment

### Full Deployment (Recommended):
1. Go to Actions → "Complete CI/CD Pipeline"
2. Click "Run workflow"
3. Select options:
   - ✅ Build Docker
   - ✅ Deploy K8s
   - ⬜ Deploy Infra (only if needed)
4. Click "Run workflow"

### Individual Workflows:
- **Terraform**: Actions → "Terraform Apply" → Run workflow
- **Docker**: Actions → "Docker Build and Push" → Run workflow
- **K8s**: Actions → "Deploy to GKE" → Run workflow

---

## Required GitHub Secrets

Set these in: Settings → Secrets and variables → Actions

### Secrets:
- `GCP_SA_KEY`: GCP service account JSON key with permissions:
  - Kubernetes Engine Admin
  - Artifact Registry Writer
  - Compute Network Admin
  - Service Account Admin

---

## Troubleshooting

### Terraform Apply fails:
- Check if GCS bucket exists: `hyperbola-476507-tfstate`
- Verify service account has permissions
- Check terraform.tfvars values

### Docker Build fails:
- Verify Artifact Registry exists
- Check app/Dockerfile syntax
- Review Trivy scan results

### K8s Deploy fails:
- Check GKE cluster is running
- Verify kubectl can connect
- Review pod logs: `kubectl logs -l app=myapp`
- Check rollback was triggered

### Workflows not triggering:
- Verify path filters match changed files
- Check branch is `main`
- Review workflow permissions

---

## Best Practices

1. **Always use Complete Pipeline** for production deployments
2. **Review Terraform plans** before approving
3. **Monitor drift detection** alerts
4. **Check security scan** results weekly
5. **Test in dev** before prod deployment
6. **Use semantic versioning** for image tags
7. **Keep secrets rotated** regularly

---

## Support

For issues or questions:
- Check workflow logs in GitHub Actions
- Review this documentation
- Check SECURITY.md for security policies
