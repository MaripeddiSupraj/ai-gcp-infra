# Terraform Destroy Testing Guide

## ⚠️ IMPORTANT: Test in Safe Environment

**NEVER test destroy on production!**

## Option 1: Terraform Plan Destroy (Safest - No Changes)

### Test what would be destroyed WITHOUT actually destroying:

```bash
cd environments/dev
terraform plan -destroy
```

**What this does**:
- ✅ Shows what WOULD be destroyed
- ✅ No actual changes made
- ✅ Safe to run anytime
- ✅ Validates destroy logic

**Output shows**:
```
Plan: 0 to add, 0 to change, 25 to destroy.
```

---

## Option 2: Create Test Environment

### Create a separate test environment to destroy:

```bash
# 1. Copy dev environment
cp -r environments/dev environments/test

# 2. Update backend to use different state
# Edit environments/test/backend.tf:
terraform {
  backend "gcs" {
    bucket = "hyperbola-476507-tfstate"
    prefix = "terraform/state/test"  # Different prefix
  }
}

# 3. Update cluster name to avoid conflicts
# Edit environments/test/terraform.tfvars:
cluster_name = "test-cluster"

# 4. Deploy test environment
cd environments/test
terraform init
terraform apply

# 5. Test destroy
terraform destroy

# 6. Cleanup test environment folder
cd ../..
rm -rf environments/test
```

---

## Option 3: Destroy Specific Resources Only

### Test destroying individual resources:

```bash
cd environments/dev

# Destroy only monitoring (safe to recreate)
terraform destroy -target=module.monitoring

# Destroy only storage bucket (if empty)
terraform destroy -target=module.storage

# Destroy only workload identity
terraform destroy -target=module.workload_identity
```

**⚠️ Warning**: This can leave orphaned resources!

---

## Option 4: Use GitHub Actions Workflow (Recommended)

### Test via workflow with approval:

```bash
# 1. Go to GitHub Actions
# 2. Select "Terraform Destroy" workflow
# 3. Click "Run workflow"
# 4. Type "DESTROY" to confirm
# 5. Workflow requires "production" environment approval
# 6. Review plan before approving
```

**Safety features**:
- ✅ Requires manual trigger
- ✅ Requires typing "DESTROY"
- ✅ Requires environment approval
- ✅ Shows plan before destroying
- ✅ Audit trail in GitHub

---

## Current Destroy Workflow Issues

### ⚠️ Problem: Auto-approve is dangerous

```yaml
# Current workflow (UNSAFE):
- name: Terraform Destroy
  run: terraform destroy -auto-approve  # ❌ No confirmation!
```

### ✅ Fix: Add plan review step

Let me create a safer destroy workflow:

```yaml
name: Terraform Destroy

on:
  workflow_dispatch:
    inputs:
      confirm:
        description: 'Type "DESTROY" to confirm'
        required: true
      environment:
        description: 'Environment to destroy'
        required: true
        type: choice
        options:
          - dev
          - test

jobs:
  plan-destroy:
    name: "Plan Destroy"
    runs-on: ubuntu-latest
    if: github.event.inputs.confirm == 'DESTROY'
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.8.5
      
      - uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Terraform Init
        working-directory: environments/${{ github.event.inputs.environment }}
        run: terraform init
      
      - name: Terraform Plan Destroy
        working-directory: environments/${{ github.event.inputs.environment }}
        run: |
          terraform plan -destroy -out=destroy.tfplan
          terraform show -no-color destroy.tfplan > destroy-plan.txt
      
      - name: Upload Destroy Plan
        uses: actions/upload-artifact@v4
        with:
          name: destroy-plan
          path: environments/${{ github.event.inputs.environment }}/destroy-plan.txt
      
      - name: Comment Plan
        run: |
          echo "## ⚠️ Destroy Plan" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          cat environments/${{ github.event.inputs.environment }}/destroy-plan.txt >> $GITHUB_STEP_SUMMARY

  destroy:
    name: "Execute Destroy"
    runs-on: ubuntu-latest
    needs: plan-destroy
    environment: 
      name: production-destroy  # Requires approval
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.8.5
      
      - uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Terraform Init
        working-directory: environments/${{ github.event.inputs.environment }}
        run: terraform init
      
      - name: Terraform Destroy
        working-directory: environments/${{ github.event.inputs.environment }}
        run: terraform destroy -auto-approve
      
      - name: Summary
        run: |
          echo "### ✅ Terraform Destroy Complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "Environment: ${{ github.event.inputs.environment }}" >> $GITHUB_STEP_SUMMARY
          echo "All infrastructure has been destroyed." >> $GITHUB_STEP_SUMMARY
```

---

## What Gets Destroyed

### Current Infrastructure:

```bash
# Check what exists
gcloud container clusters list
gcloud compute networks list
gcloud artifacts repositories list
gcloud storage buckets list
```

### Resources that will be destroyed:

1. **GKE Cluster** - `primary-cluster-v2`
   - All pods and workloads
   - Node pools
   - ⚠️ Data loss: All running applications

2. **Networking**
   - VPC: `gke-network-v2`
   - Subnets
   - Cloud NAT
   - Firewall rules

3. **Storage**
   - Artifact Registry: `docker-repo`
   - Cloud Storage bucket: `{project}-chat-sessions`
   - ⚠️ Data loss: All stored data

4. **IAM**
   - Service accounts
   - Workload Identity bindings
   - IAM roles

5. **Monitoring** (if deployed)
   - Prometheus
   - Grafana
   - ⚠️ Data loss: All metrics history

---

## Pre-Destroy Checklist

Before destroying, ensure:

- [ ] Backup any important data
- [ ] Export Grafana dashboards
- [ ] Save Docker images from Artifact Registry
- [ ] Document any manual configurations
- [ ] Notify team members
- [ ] Verify no production traffic
- [ ] Check for dependent resources

---

## Backup Commands

### Before destroying, backup:

```bash
# 1. Export Grafana dashboards
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
# Export dashboards via UI

# 2. List all Docker images
gcloud artifacts docker images list us-central1-docker.pkg.dev/hyperbola-476507/docker-repo

# 3. Pull important images
docker pull us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:latest

# 4. Export Kubernetes configs
kubectl get all -A -o yaml > k8s-backup.yaml

# 5. Export Terraform state
cd environments/dev
terraform state pull > terraform-state-backup.json
```

---

## Recovery After Destroy

### To recreate infrastructure:

```bash
cd environments/dev
terraform init
terraform apply
```

**Note**: 
- State file in GCS is preserved
- Can recreate identical infrastructure
- Need to redeploy applications
- Need to reconfigure monitoring

---

## Recommended Testing Approach

### For your case:

1. **Use `terraform plan -destroy`** (safest)
   ```bash
   cd environments/dev
   terraform plan -destroy > destroy-plan.txt
   cat destroy-plan.txt
   ```

2. **Review what would be destroyed**
   - Check if all resources are listed
   - Verify no unexpected resources
   - Confirm destroy logic works

3. **Don't actually destroy** (keep infrastructure running)

4. **Fix destroy workflow** (add approval step)

---

## Test Now (Safe)

Want me to run `terraform plan -destroy` to show what would be destroyed?

```bash
cd environments/dev
terraform plan -destroy
```

This is 100% safe - no changes will be made!
