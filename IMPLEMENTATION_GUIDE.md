# Implementation Guide: Production-Ready GCP Terraform + Kubernetes

**Last Updated:** 2024  
**Status:** Ready for Implementation  
**Estimated Effort:** 8-12 hours spread over 2-3 sprints

---

## Overview

This guide provides step-by-step instructions to implement the audit recommendations and move from "good" to "excellent" production-grade setup.

---

## PHASE 1: Workflow Cleanup (30 minutes)

### Objective
Remove duplicate/empty workflow files and consolidate to 3 main workflows.

### Current State
15 workflow files with redundancy:
- 3 Terraform workflows that conflict (terraform.yml, terraform-apply.yml, terraform-check.yml, terraform-plan.yml)
- 3 empty placeholder files (ai-docker-build.yml, ai-k8s-deploy.yml, ai-complete-pipeline.yml)
- 8 other workflows (some useful, some not)

### Recommended Action

**Step 1: Identify workflows to remove**

```bash
cd /Users/maripeddisupraj/Desktop/ai-gcp-infra/.github/workflows

# Files to DELETE:
# 1. terraform-apply.yml (superseded by terraform.yml)
# 2. terraform-check.yml (superseded by terraform.yml)
# 3. terraform-plan.yml (superseded by terraform.yml)
# 4. ai-docker-build.yml (empty)
# 5. ai-k8s-deploy.yml (empty)
# 6. ai-complete-pipeline.yml (empty)

# Files to REVIEW (optional cleanup):
# - terraform-drift.yml (useful for scheduled drift detection)
# - terraform-destroy.yml (emergency workflow, keep but document)
# - security-scan.yml (can be consolidated into terraform.yml)
# - unlock-state.yml (emergency workflow, keep)
```

**Step 2: Keep only essential workflows**

The recommended set:

1. **terraform.yml** - Main infrastructure pipeline
   - Status: ✅ Already created and excellent
   - Handles: PR plan-only, main apply with approval, manual destroy
   - Keep as-is

2. **docker-build-push.yml** - Container CI/CD
   - Status: ✅ Already created and excellent
   - Handles: PR build+scan, main build+scan+push
   - Keep as-is

3. **k8s-deploy.yml** - Kubernetes deployment
   - Status: ✅ Functional, minor improvements needed
   - Handles: Manifest deployment with validation
   - Keep with improvements (see Phase 2)

**Step 3: Clean up**

```bash
# Remove old/empty files
rm -f terraform-apply.yml
rm -f terraform-check.yml
rm -f terraform-plan.yml
rm -f ai-docker-build.yml
rm -f ai-k8s-deploy.yml
rm -f ai-complete-pipeline.yml

# Optional cleanup (decide based on your needs)
# rm -f terraform-drift.yml  # Uncomment if not needed
# rm -f security-scan.yml    # Can consolidate later
```

**Step 4: Document decision**

Create a file `.github/WORKFLOWS.md`:

```markdown
# GitHub Actions Workflows

## Active Workflows

### 1. terraform.yml
- **Purpose:** Infrastructure-as-Code pipeline
- **Triggers:** PR (plan-only), main push (plan + approval + apply)
- **Features:** Validation, planning, approval gates, checksum verification

### 2. docker-build-push.yml
- **Purpose:** Container image CI/CD
- **Triggers:** PR (build + scan), main push (build + scan + push)
- **Features:** Trivy scanning, SBOM, security checks

### 3. k8s-deploy.yml
- **Purpose:** Kubernetes deployment
- **Triggers:** k8s-manifests/ path changes, manual dispatch
- **Features:** Manifest validation, sequential deployment

## Removed Workflows

Consolidated into main workflows:
- terraform-apply.yml → terraform.yml
- terraform-check.yml → terraform.yml
- terraform-plan.yml → terraform.yml
- ai-*.yml → consolidated

## Optional Workflows

These can be added later:
- terraform-drift.yml (detect configuration drift)
- cost-estimation.yml (Infracost integration)
- security-scan-scheduled.yml (nightly security scans)
```

---

## PHASE 2: Security Enhancements (2 hours)

### Objective
Add container image signing, enhanced security scanning, and disaster recovery.

### 2.1 Add Container Image Signing (cosign)

**Motivation:**
- Cryptographically verify image provenance
- Meet compliance requirements
- Prevent image tampering

**Implementation:**

1. **Generate signing key** (local, run once):
```bash
# Generate a cosign key pair
cosign generate-key-pair

# This creates:
# - cosign.key (private, secret!)
# - cosign.pub (public, can share)

# Store as GitHub Secret:
# Name: COSIGN_PRIVATE_KEY
# Value: $(cat cosign.key)
```

2. **Update docker-build-push.yml:**

Add to the workflow after pushing the image:

```yaml
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3
        with:
          cosign-version: latest

      - name: Sign Docker Image
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        env:
          COSIGN_EXPERIMENTAL: 1
        run: |
          cosign sign --key env://COSIGN_PRIVATE_KEY \
            ${{ steps.meta.outputs.image }}:${{ github.sha }}
```

3. **Verify signature (manual test):**

```bash
cosign verify --key cosign.pub \
  us-central1-docker.pkg.dev/PROJECT/docker-repo/app:COMMIT_SHA
```

### 2.2 Add Bandit + Safety Security Scanning

**Motivation:**
- Detect Python security vulnerabilities
- Check for known dangerous functions
- Identify insecure patterns

**Implementation:**

1. **Update app/requirements.txt:**

```txt
flask==3.0.0
gunicorn==21.2.0
# Dev dependencies would go in requirements-dev.txt
```

2. **Create app/requirements-dev.txt:**

```txt
pytest==7.4.0
pytest-cov==4.1.0
black==23.10.0
flake8==6.1.0
bandit==1.7.5
safety==2.3.5
```

3. **Update docker-build-push.yml** - Add security scanning step:

```yaml
      - name: Run Bandit Security Check
        run: |
          pip install bandit
          bandit -r app/ -f json -o bandit-report.json || true
          cat bandit-report.json | jq '.'

      - name: Run Safety Check
        run: |
          pip install safety
          safety check --json > safety-report.json || true
          cat safety-report.json | jq '.'

      - name: Upload Security Reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: security-reports-${{ github.sha }}
          path: |
            bandit-report.json
            safety-report.json
          retention-days: 30
```

### 2.3 Enable GKE Backup API

**Motivation:**
- Disaster recovery for cluster data
- Compliance requirement
- Quick recovery from accidental deletions

**Implementation:**

1. **Update modules/gke/main.tf** - Add backup configuration:

```terraform
# Add to google_container_cluster resource
resource "google_container_backup_restore_backup_plan" "backup" {
  name   = "${var.cluster_name}-backup"
  cluster = google_container_cluster.primary.id
  location = var.region
  project = var.project_id
  
  backup_config {
    include_volume_data      = true
    include_secrets          = true
    all_namespaces           = true
  }

  backup_schedule {
    cron_schedule = "0 2 * * *"  # Daily at 2 AM UTC
  }

  retention_policy {
    backup_delete_lock_days  = 0
    backup_retain_days       = 30
  }
}
```

2. **Enable Backup API in GCP**:

```bash
gcloud services enable gkebackup.googleapis.com \
  --project=hyperbola-476507
```

3. **Verify in terraform.tfvars:**

```terraform
# No changes needed, backup is automatic
```

### 2.4 Add Deletion Protection to Production

**Motivation:**
- Prevent accidental cluster destruction
- One-step safety check

**Implementation:**

1. **Update modules/gke/variables.tf:**

```terraform
variable "enable_deletion_protection" {
  type        = bool
  description = "Protect cluster from accidental deletion"
  default     = false
}
```

2. **Update modules/gke/main.tf:**

```terraform
resource "google_container_cluster" "primary" {
  # ... existing config ...
  deletion_protection = var.enable_deletion_protection
}
```

3. **Update main.tf:**

```terraform
module "gke_standard" {
  # ... existing config ...
  enable_deletion_protection = var.environment == "prod" ? true : false
}
```

4. **Add to terraform.tfvars:**

```terraform
environment = "prod"  # or "dev", "staging"
```

---

## PHASE 3: Kubernetes Improvements (2 hours)

### Objective
Use Kustomize for better manifest management and add health checks.

### 3.1 Convert to Kustomize

**Current Issue:**
Using `sed` to patch image tags is fragile and error-prone.

**Solution:**
Use Kustomize overlays for clean, declarative configuration.

**Implementation:**

1. **Create kustomization.yaml files**

Structure:
```
k8s-manifests/
├── base/
│   ├── kustomization.yaml       # NEW
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ...
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml   # NEW
    │   └── deployment-patch.yaml # NEW
    └── prod/
        ├── kustomization.yaml   # NEW
        └── deployment-patch.yaml # NEW
```

2. **Create base/kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: ai-app

resources:
  - deployment.yaml
  - service.yaml
  - hpa.yaml

commonLabels:
  app: myapp
  managed-by: kustomize

images:
  - name: app
    newName: us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/app
    newTag: latest
```

3. **Create overlays/prod/kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: prod

bases:
  - ../../base

patchesStrategicMerge:
  - deployment-patch.yaml

replicas:
  - name: app
    count: 3

images:
  - name: app
    newTag: latest  # Will be overridden by workflow
```

4. **Create overlays/prod/deployment-patch.yaml:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      priorityClassName: high-priority
      nodeSelector:
        workload-type: on-demand
```

5. **Update k8s-deploy.yml workflow:**

Replace the fragile sed approach with:

```yaml
      - name: Deploy with Kustomize
        run: |
          # Set image tag
          cd k8s-manifests/overlays/prod
          
          kustomize edit set image app=\
            us-central1-docker.pkg.dev/${{ steps.config.outputs.project_id }}/\
            ${{ steps.config.outputs.repository_id }}/app:${{ inputs.image_tag || 'latest' }}
          
          # Apply manifests
          kubectl apply -k .
          
          # Wait for rollout
          kubectl rollout status deployment/app -n prod --timeout=5m
```

### 3.2 Add Pod Disruption Budgets

**Motivation:**
- Protect against voluntary disruptions (node drain, cluster upgrades)
- Ensure minimum availability during maintenance

**Implementation:**

1. **Create k8s-manifests/base/pod-disruption-budget.yaml:**

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: myapp
```

2. **For production (stricter):**

Create `overlays/prod/pod-disruption-budget-patch.yaml`:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2  # At least 2 pods always available
```

3. **Update base/kustomization.yaml:**

```yaml
resources:
  - deployment.yaml
  - service.yaml
  - hpa.yaml
  - pod-disruption-budget.yaml  # ADD THIS
```

### 3.3 Add Startup Probes

**Motivation:**
- Handle apps with long startup times
- Prevent premature kill during initialization

**Implementation:**

Update `k8s-manifests/base/deployment.yaml`:

```yaml
containers:
- name: app
  image: us-central1-docker.pkg.dev/...
  ports:
  - containerPort: 8080
    name: http
  
  # Add startup probe (new)
  startupProbe:
    httpGet:
      path: /health
      port: 8080
    failureThreshold: 30
    periodSeconds: 10  # Probe every 10s for up to 5 minutes
  
  # Keep existing probes
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 10
    periodSeconds: 10
  
  readinessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5
```

### 3.4 Add Rollback Automation

**Motivation:**
- Automatic rollback if deployment fails
- Zero-downtime recovery

**Implementation:**

Update `k8s-deploy.yml` workflow:

```yaml
      - name: Deploy with Kustomize
        id: deploy
        run: |
          kubectl apply -k k8s-manifests/overlays/prod/
          echo "deploy-status=success" >> $GITHUB_OUTPUT

      - name: Wait for Rollout
        if: steps.deploy.outputs.deploy-status == 'success'
        run: |
          kubectl rollout status deployment/app -n prod --timeout=5m

      - name: Rollback on Failure
        if: failure()
        run: |
          echo "🔄 Rolling back deployment..."
          kubectl rollout undo deployment/app -n prod
          kubectl rollout status deployment/app -n prod --timeout=5m
          echo "✅ Rollback completed"
```

---

## PHASE 4: Observability & Monitoring (3 hours)

### Objective
Add cost monitoring, APM tracing, and comprehensive dashboards.

### 4.1 Add Infracost for Cost Estimation

**Motivation:**
- Predict cost impact of infrastructure changes
- Prevent budget overruns
- Identify optimization opportunities

**Implementation:**

1. **Get Infracost API key:**

```bash
# Register at https://www.infracost.io/
# Get API key from dashboard
# Store as GitHub Secret: INFRACOST_API_KEY
```

2. **Update terraform.yml workflow**:

Add after terraform plan:

```yaml
      - name: Run Infracost
        uses: infracost/actions@v2
        with:
          path: .
          api_key: ${{ secrets.INFRACOST_API_KEY }}
          format: table

      - name: Comment PR with Cost Estimate
        if: github.event_name == 'pull_request'
        uses: infracost/actions@v2
        with:
          path: .
          api_key: ${{ secrets.INFRACOST_API_KEY }}
          post_condition: always
```

### 4.2 Add Cloud Monitoring Dashboard

**Motivation:**
- Centralized view of cluster health
- Quick incident response
- Historical trend analysis

**Implementation:**

Create `modules/monitoring/dashboard.tf`:

```terraform
resource "google_monitoring_dashboard" "gke_cluster" {
  dashboard_json = jsonencode({
    displayName = "GKE Cluster Health"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Pod CPU Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=k8s_pod AND metric.type=kubernetes.io/pod/cpu/core_usage_time"
                  }
                }
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Pod Memory Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=k8s_pod AND metric.type=kubernetes.io/pod/memory/used_bytes"
                  }
                }
              }]
            }
          }
        },
        # Add more tiles for other metrics
      ]
    }
  })
  project = var.project_id
}

output "dashboard_url" {
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.gke_cluster.id}"
  description = "URL to the GKE cluster monitoring dashboard"
}
```

### 4.3 Enable Cloud Trace for APM

**Motivation:**
- Distributed tracing for requests
- Performance bottleneck identification
- Latency analysis

**Implementation:**

1. **Enable Trace API:**

```bash
gcloud services enable cloudtrace.googleapis.com \
  --project=hyperbola-476507
```

2. **Update app/app.py** for tracing:

```python
from flask import Flask
from google.cloud import trace_v2
import google.cloud.trace_exporter
from opentelemetry import trace
from opentelemetry.exporter.gcp_trace import CloudTraceExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor

# Initialize tracing
tracer_provider = TracerProvider()
trace.set_tracer_provider(tracer_provider)
tracer_provider.add_span_processor(
    SimpleSpanProcessor(CloudTraceExporter())
)

app = Flask(__name__)
tracer = trace.get_tracer(__name__)

@app.route('/')
def hello():
    with tracer.start_as_current_span("hello_handler") as span:
        span.set_attribute("user.request", "GET /")
        return {'message': 'Hello from GKE!', 'status': 'running'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

3. **Update app/requirements.txt:**

```txt
flask==3.0.0
gunicorn==21.2.0
google-cloud-trace==1.10.0
opentelemetry-api==1.20.0
opentelemetry-sdk==1.20.0
opentelemetry-exporter-gcp-trace==0.41b0
```

---

## PHASE 5: Governance & Documentation (1 hour)

### Objective
Add code governance, CODEOWNERS, and comprehensive documentation.

### 5.1 Add CODEOWNERS File

**Motivation:**
- Automatic review assignments
- Code ownership clarity
- Enforce review requirements

**Implementation:**

Create `.github/CODEOWNERS`:

```bash
# Root level
* @team/platform

# Terraform
*.tf @team/infrastructure
modules/ @team/infrastructure
*.tfvars @team/infrastructure

# Kubernetes
k8s-manifests/ @team/platform
k8s-examples/ @team/platform

# Application
app/ @team/dev
app/Dockerfile @team/dev
app/requirements.txt @team/dev

# Workflows
.github/workflows/ @team/infrastructure

# Documentation
*.md @team/platform
```

### 5.2 Create Contributing Guide

Create `CONTRIBUTING.md`:

```markdown
# Contributing Guide

## Terraform Changes

1. Make changes to `modules/` or root `.tf` files
2. Run `terraform fmt -recursive`
3. Submit PR - will run validation and plan
4. Review the plan comment
5. Approval needed before apply

## Kubernetes Changes

1. Update manifests in `k8s-manifests/`
2. Validate: `kubectl apply --dry-run=client -f k8s-manifests/`
3. Submit PR
4. After merge, deploy workflow runs

## Docker/App Changes

1. Update `app/` files
2. Update `app/requirements.txt` if needed
3. Submit PR - builds and scans
4. After merge, image is built, scanned, and pushed
5. K8s deployment is auto-triggered

## Security Checklist

- [ ] No secrets in code
- [ ] Images scanned with Trivy
- [ ] Python code checked with Bandit
- [ ] Terraform scanned with Checkov
- [ ] Container runs as non-root
- [ ] Security context defined

## Testing

```bash
# Terraform
terraform validate
terraform plan

# Python
pytest app/tests/
bandit -r app/

# Docker
docker build -t test:latest app/
docker run --rm test:latest
```
```

### 5.3 Create Disaster Recovery Runbook

Create `DISASTER_RECOVERY.md`:

```markdown
# Disaster Recovery Runbook

## Cluster Failure

### Scenario: Entire cluster down

1. **Detect:** Monitoring alerts + manual check
   ```bash
   gcloud container clusters list --project=hyperbola-476507
   ```

2. **Assess:** Check cluster status
   ```bash
   gcloud container clusters describe primary-cluster \
     --location=us-central1 --project=hyperbola-476507
   ```

3. **Restore from backup:**
   ```bash
   gcloud container backup-restore restores create \
     --source=BACKUP_ID \
     --cluster=CLUSTER_NAME \
     --location=us-central1
   ```

4. **Verify:** Run smoke tests
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

## State Corruption

### Scenario: Terraform state corrupted

1. **Access backup state:**
   ```bash
   gsutil ls -r gs://hyperbola-476507-tfstate/
   gsutil cp gs://hyperbola-476507-tfstate/terraform/state/default.tfstate backup.tfstate
   ```

2. **Validate:**
   ```bash
   terraform state list
   terraform plan
   ```

3. **If needed, restore:**
   ```bash
   gsutil cp backup.tfstate gs://hyperbola-476507-tfstate/terraform/state/default.tfstate
   ```

## Database/Application Recovery

1. **Check pod logs:**
   ```bash
   kubectl logs -f deployment/app -n default
   ```

2. **Restart pods:**
   ```bash
   kubectl delete pod -l app=myapp -n default
   ```

3. **Rollback deployment:**
   ```bash
   kubectl rollout history deployment/app -n default
   kubectl rollout undo deployment/app -n default
   ```

4. **Redeploy:**
   ```bash
   kubectl apply -k k8s-manifests/overlays/prod/
   ```

## Cost Anomaly

1. **Check current spending:**
   ```bash
   gcloud billing accounts list
   gcloud billing budgets list --billing-account=ACCOUNT_ID
   ```

2. **Identify expensive resources:**
   ```bash
   gcloud compute instances list
   gcloud container clusters list
   ```

3. **Take action:**
   - Scale down if appropriate
   - Review and delete unused resources
   - Adjust budget alerts
```

---

## PHASE 6: Testing & Validation (2 hours)

### Objective
Verify all changes work end-to-end.

### 6.1 Test Terraform Pipeline

```bash
# 1. Create a test branch
git checkout -b test/terraform-pipeline

# 2. Make a small change
echo "# Test change" >> main.tf

# 3. Push and create PR
git add main.tf
git commit -m "test: terraform pipeline"
git push origin test/terraform-pipeline

# 4. Verify on GitHub:
# - PR is created
# - Terraform validation runs
# - Plan is shown in PR comments
# - ✅ Expected: Plan-only, no apply

# 5. Merge PR to main
# - Verify approval gate is required
# - Approve from GitHub UI (Environments)
# - Verify apply runs
# - ✅ Expected: Plan + apply completes
```

### 6.2 Test Docker Pipeline

```bash
# 1. Create test branch
git checkout -b test/docker-pipeline

# 2. Update app
echo 'print("test")' >> app/app.py

# 3. Push and create PR
git add app/
git commit -m "test: docker pipeline"
git push origin test/docker-pipeline

# 4. Verify:
# - Docker build runs
# - Trivy scanning completes
# - ✅ Expected: No push to registry (PR only)

# 5. Merge to main
# - Verify image is pushed
# - Verify K8s deploy is triggered
# - ✅ Expected: Image in GAR, pods updating
```

### 6.3 Test K8s Deployment

```bash
# 1. Get credentials
gcloud container clusters get-credentials primary-cluster \
  --location=us-central1

# 2. Check deployment
kubectl get deployment -n default
kubectl describe deployment app -n default

# 3. Check pods
kubectl get pods -n default
kubectl logs deployment/app -n default

# 4. Test service
kubectl port-forward svc/app 8080:8080 &
curl http://localhost:8080/health
# ✅ Expected: {"status": "healthy"}

# 5. Test health checks
kubectl exec -it deployment/app -- curl http://localhost:8080/health
# ✅ Expected: {"status": "healthy"}
```

---

## PHASE 7: Production Deployment Checklist

Complete this before deploying to production:

```bash
# Infrastructure
- [ ] GCS state bucket created (hyperbola-476507-tfstate)
- [ ] Terraform backend configured
- [ ] GitHub Secrets configured:
    - [ ] GCP_SA_KEY (service account JSON)
    - [ ] COSIGN_PRIVATE_KEY (for image signing)
    - [ ] INFRACOST_API_KEY (for cost estimation)

# Kubernetes
- [ ] GKE cluster created and accessible
- [ ] Namespaces created (default, prod, dev)
- [ ] Network policies deployed
- [ ] Pod security policies enabled
- [ ] RBAC configured

# Security
- [ ] Workload Identity pools configured
- [ ] GitHub Actions federation set up
- [ ] Container image signing working
- [ ] Security scanning enabled (Trivy, Bandit, Safety)

# Monitoring
- [ ] Alert email configured
- [ ] Monitoring dashboard created
- [ ] Cost alerts set up
- [ ] Log retention configured

# CI/CD
- [ ] All 3 workflows active (terraform, docker, k8s)
- [ ] Approval gates configured
- [ ] Artifact retention set
- [ ] Notifications configured

# Documentation
- [ ] CONTRIBUTING.md created
- [ ] DISASTER_RECOVERY.md created
- [ ] Architecture diagram in README
- [ ] Team trained on workflows

# Testing
- [ ] Terraform plan verified
- [ ] Terraform apply verified
- [ ] Docker build/push verified
- [ ] K8s deployment verified
- [ ] End-to-end smoke test passed

# Approval
- [ ] Security review completed
- [ ] Cost review completed
- [ ] Architecture review completed
- [ ] Team sign-off obtained

# Go-Live
- [ ] Database backups verified
- [ ] Disaster recovery tested
- [ ] Runbooks documented
- [ ] On-call rotations set
- [ ] Monitoring alerts tested
- [ ] Incident response plan reviewed
```

---

## Implementation Timeline

### Week 1: Phase 1 & 2 (Cleanup + Security)
- Monday: Phase 1 cleanup (30 min)
- Tuesday-Wednesday: Phase 2 security (cosign, bandit, safety)
- Thursday-Friday: Testing and fixes

### Week 2: Phase 3 (Kubernetes)
- Monday: Phase 3 Kustomize setup
- Tuesday: Add PDBs and startup probes
- Wednesday: Add rollback automation
- Thursday-Friday: Testing

### Week 3: Phase 4 & 5 (Observability + Governance)
- Monday-Tuesday: Phase 4 monitoring setup
- Wednesday: Phase 5 documentation
- Thursday-Friday: Final testing

### Go-Live
- Week 4: Production deployment

---

## Commands Reference

### Quick Setup

```bash
# 1. Cleanup workflows
cd .github/workflows
rm -f terraform-apply.yml terraform-check.yml terraform-plan.yml
rm -f ai-*.yml

# 2. Initialize Kustomize
cd k8s-manifests/base
kustomize create --autodetect

# 3. Initialize overlay
cd ../overlays/prod
kustomize create --autodetect

# 4. Enable APIs
gcloud services enable gkebackup.googleapis.com
gcloud services enable cloudtrace.googleapis.com

# 5. Test Terraform
terraform validate
terraform fmt -recursive
```

### Validation Commands

```bash
# Validate Terraform
terraform plan -out=tfplan
terraform show -json tfplan | jq '.resource_changes'

# Validate K8s manifests
kubectl apply --dry-run=client -f k8s-manifests/

# Validate Docker
docker build -t test:latest app/
docker run --rm test:latest /app

# Validate security
bandit -r app/
safety check
trivy image test:latest
```

---

## Success Metrics

After implementation, verify:

- ✅ Terraform workflow runs on PR (plan-only)
- ✅ Terraform apply requires approval on main
- ✅ Docker builds and scans on PR
- ✅ Docker pushes only on main
- ✅ K8s deployment auto-triggers after docker push
- ✅ Cost estimation visible in PRs
- ✅ Security scanning shows no HIGH/CRITICAL issues
- ✅ Monitoring dashboard shows cluster health
- ✅ All team members can execute workflows
- ✅ Rollback works within 2 minutes

---

## Support & Questions

Refer to:
- `PRODUCTION_AUDIT_REPORT.md` - Detailed audit findings
- `WORKFLOWS.md` - Workflow documentation
- `CONTRIBUTING.md` - Development guidelines
- `DISASTER_RECOVERY.md` - Emergency procedures

---

**Ready to implement? Start with Phase 1 cleanup!**
