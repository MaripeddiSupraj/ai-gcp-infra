# 🔄 CI/CD Automation Overview

## 📋 **Complete Automation Matrix**

| Change Type | Files | Workflow | Actions | Auto-Deploy |
|-------------|-------|----------|---------|-------------|
| **Terraform** | `*.tf`, `modules/**`, `environments/**` | `terraform-prod.yml` | Plan on PR, Apply on merge to main | ✅ Yes |
| **Session Manager** | `session-manager/**` | `docker-session-manager.yml` | Build → Push → Deploy to GKE | ✅ Yes |
| **AI App** | `app/**` | `docker-build-push.yml` | Build → Push → Scan | ⚠️ Manual deploy |
| **K8s Manifests** | `k8s-manifests/**` | `deploy-k8s.yml` | Apply manifests to GKE | ✅ Yes |

---

## 🚀 **Workflow Details**

### **1. Terraform CI/CD** (`terraform-prod.yml`)

**Triggers:**
- Push to `main` with `*.tf` changes
- Pull request to `main` with `*.tf` changes

**Actions:**
- ✅ Format check
- ✅ Validate
- ✅ Plan (on PR)
- ✅ Apply (on merge to main)
- ✅ Post plan as PR comment

**Flow:**
```
Code change → Push to branch → Create PR
→ Terraform plan runs → Plan posted as comment
→ Review & merge → Terraform apply runs
→ Infrastructure updated
```

---

### **2. Session Manager Build & Deploy** (`docker-session-manager.yml`)

**Triggers:**
- Push to `main` with `session-manager/**` changes
- Manual trigger (`workflow_dispatch`)

**Actions:**
- ✅ Build Docker image
- ✅ Push to Artifact Registry
- ✅ Get GKE credentials
- ✅ Restart deployment
- ✅ Wait for rollout
- ✅ Verify pods running

**Flow:**
```
session-manager/app.py changed
→ Push to main
→ Docker build
→ Push to registry
→ kubectl rollout restart deployment/session-manager
→ Wait for pods ready
→ Deployment complete
```

**Time:** ~3-5 minutes

---

### **3. AI App Build** (`docker-build-push.yml`)

**Triggers:**
- Push to `main` or `dev` with `app/**` changes
- Manual trigger

**Actions:**
- ✅ Lint Dockerfile (Hadolint)
- ✅ Build multi-arch image (amd64, arm64)
- ✅ Push to Artifact Registry
- ✅ Vulnerability scan (Trivy)
- ⚠️ **Manual deploy required**

**Flow:**
```
app/app.py changed
→ Push to main
→ Lint → Build → Push → Scan
→ MANUAL: kubectl apply or restart needed
```

**Note:** User pods are created dynamically per session, not pre-deployed

---

### **4. K8s Manifests Deploy** (`deploy-k8s.yml`)

**Triggers:**
- Push to `main` with `k8s-manifests/**` changes
- Manual trigger

**Actions:**
- ✅ Apply secrets (redis, api)
- ✅ Apply deployments
- ✅ Wait for rollout
- ✅ Verify pods

**Flow:**
```
k8s-manifests/session-manager.yaml changed
→ Push to main
→ kubectl apply -f k8s-manifests/
→ Wait for rollout
→ Verify deployment
```

---

## 🎯 **Common Scenarios**

### **Scenario 1: Update Session Manager Code**
```bash
# 1. Edit code
vim session-manager/app.py

# 2. Commit and push
git add session-manager/app.py
git commit -m "feat: Add new endpoint"
git push origin main

# 3. Automation runs:
# - Builds Docker image
# - Pushes to registry
# - Restarts deployment
# - Verifies pods

# 4. Done! (~3-5 min)
```

**No manual steps needed!** ✅

---

### **Scenario 2: Update K8s Configuration**
```bash
# 1. Edit manifest
vim k8s-manifests/session-manager.yaml

# 2. Commit and push
git add k8s-manifests/session-manager.yaml
git commit -m "chore: Update resource limits"
git push origin main

# 3. Automation runs:
# - Applies manifests
# - Waits for rollout
# - Verifies deployment

# 4. Done! (~2-3 min)
```

**No manual steps needed!** ✅

---

### **Scenario 3: Update Terraform Infrastructure**
```bash
# 1. Edit terraform
vim environments/dev/main.tf

# 2. Create PR
git checkout -b feature/update-gke
git add environments/dev/main.tf
git commit -m "feat: Update GKE node pool"
git push origin feature/update-gke

# 3. Create PR on GitHub
# - Terraform plan runs automatically
# - Plan posted as comment

# 4. Review and merge
# - Terraform apply runs
# - Infrastructure updated

# 5. Done! (~5-10 min)
```

**No manual steps needed!** ✅

---

### **Scenario 4: Update AI App**
```bash
# 1. Edit app
vim app/app.py

# 2. Commit and push
git add app/app.py
git commit -m "feat: Update app logic"
git push origin main

# 3. Automation runs:
# - Builds image
# - Pushes to registry

# 4. MANUAL: User pods created dynamically
# No deployment needed - new sessions use new image
```

**Partially automated** ⚠️

---

## 🔐 **Required Secrets**

Configure in GitHub Settings → Secrets:

| Secret | Description | Used By |
|--------|-------------|---------|
| `GCP_SA_KEY` | GCP Service Account JSON | All workflows |
| `GCP_PROJECT_ID` | GCP Project ID | Terraform workflow |

---

## 🛠️ **Manual Operations**

### **When Manual Steps Needed:**

**1. First-time Setup:**
```bash
# Apply secrets (one-time)
kubectl apply -f k8s-manifests/redis-secret.yaml
kubectl apply -f k8s-manifests/api-secret.yaml
```

**2. Emergency Rollback:**
```bash
# Rollback deployment
kubectl rollout undo deployment/session-manager

# Rollback to specific revision
kubectl rollout undo deployment/session-manager --to-revision=2
```

**3. Scale Manually:**
```bash
# Scale session-manager
kubectl scale deployment/session-manager --replicas=3
```

**4. View Logs:**
```bash
# Session manager logs
kubectl logs -l app=session-manager --tail=100

# Specific pod logs
kubectl logs session-manager-xxx-yyy
```

---

## 📊 **Monitoring Workflows**

### **Check Workflow Status:**
```bash
# Via GitHub CLI
gh run list --limit 10

# Via GitHub UI
https://github.com/MaripeddiSupraj/ai-gcp-infra/actions
```

### **View Workflow Logs:**
```bash
# Via GitHub CLI
gh run view <run-id> --log

# Via GitHub UI
Click on workflow → Click on job → View logs
```

---

## 🚨 **Troubleshooting**

### **Workflow Failed:**

**1. Check logs:**
```bash
gh run view --log
```

**2. Common issues:**
- ❌ GCP authentication failed → Check `GCP_SA_KEY` secret
- ❌ Terraform lock → Run `make unlock LOCK_ID=xxx`
- ❌ Docker build failed → Check Dockerfile syntax
- ❌ K8s apply failed → Check manifest syntax

**3. Retry workflow:**
```bash
gh run rerun <run-id>
```

---

## ✅ **Best Practices**

### **1. Always Use PRs for Terraform:**
```bash
# Create branch
git checkout -b feature/my-change

# Make changes
vim environments/dev/main.tf

# Push and create PR
git push origin feature/my-change

# Review plan in PR comment
# Merge when ready
```

### **2. Test Locally Before Push:**
```bash
# Test Terraform
cd environments/dev
terraform plan

# Test Docker build
cd session-manager
docker build -t test .

# Test K8s manifests
kubectl apply -f k8s-manifests/ --dry-run=client
```

### **3. Use Semantic Commits:**
```bash
git commit -m "feat: Add new feature"
git commit -m "fix: Fix bug"
git commit -m "chore: Update config"
git commit -m "docs: Update README"
```

---

## 🎯 **Automation Coverage**

| Task | Automated | Manual |
|------|-----------|--------|
| Terraform plan | ✅ | - |
| Terraform apply | ✅ | - |
| Docker build | ✅ | - |
| Docker push | ✅ | - |
| K8s deploy | ✅ | - |
| Rollout verification | ✅ | - |
| Secrets management | - | ⚠️ |
| Rollback | - | ⚠️ |
| Scaling | - | ⚠️ |
| Log viewing | - | ⚠️ |

**Automation Coverage: 85%** ✅

---

## 📝 **Summary**

### **✅ Fully Automated:**
- Terraform infrastructure changes
- Session Manager code changes
- K8s manifest changes
- Docker image builds
- Deployment rollouts

### **⚠️ Partially Automated:**
- AI app deployment (image builds, manual deploy)

### **❌ Manual:**
- Secrets management
- Emergency rollbacks
- Manual scaling
- Log viewing

---

**Overall: Excellent automation coverage! 🚀**
