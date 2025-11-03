# Docker Workflow Deployment Guide

## 🚀 When Images Are Pushed to Registry

### Automatic Push Scenarios:

| Scenario | Trigger | Tags Created | Environment |
|----------|---------|--------------|-------------|
| **Push to `main`** | Direct commit or PR merge | `sha` + `latest` | Production (requires approval) |
| **Push to `dev`** | Direct commit or PR merge | `sha` + `dev` | Development (auto-deploy) |
| **Manual Trigger** | workflow_dispatch | `sha` + branch tag | Selected environment |

### Build-Only Scenarios (No Push):

| Scenario | Trigger | Action |
|----------|---------|--------|
| **Pull Request** | PR to main/dev | Build + Security Scan + Report |

---

## 📋 Deployment Approaches

### Approach 1: PR-Based Workflow (RECOMMENDED)

**Best for:** Production environments, team collaboration

```bash
# 1. Create feature branch
git checkout -b feature/optimize-dockerfile

# 2. Make changes and commit
git add app/
git commit -m "Optimize Dockerfile with multi-stage build"

# 3. Push to feature branch
git push origin feature/optimize-dockerfile

# 4. Create Pull Request on GitHub
# - Workflow runs: Build + Security Scan
# - Review security findings in PR
# - Team reviews code changes

# 5. Merge PR to main
# - Triggers production build
# - Requires manual approval (if configured)
# - Pushes to registry with 'latest' tag
```

**Advantages:**
- ✅ Code review before deployment
- ✅ Security scan results visible in PR
- ✅ Team approval required
- ✅ Audit trail of changes
- ✅ Can revert easily

---

### Approach 2: Direct Push (Current Setup)

**Best for:** Solo development, rapid iteration, dev environment

```bash
# 1. Make changes locally
git add app/

# 2. Commit changes
git commit -m "Update Dockerfile"

# 3. Push directly to main
git push origin main

# Result: Immediate build and push to registry
```

**Advantages:**
- ⚡ Fastest deployment
- ⚡ No approval gates
- ⚡ Good for development

**Disadvantages:**
- ⚠️ No review process
- ⚠️ Higher risk for production

---

### Approach 3: Manual Approval (PRODUCTION-GRADE)

**Best for:** Production deployments with strict controls

**Setup Required:**
1. Go to GitHub Repository → Settings → Environments
2. Create environment: `production`
3. Add required reviewers
4. Enable "Required reviewers" protection

**Workflow:**
```bash
# 1. Merge PR to main
# 2. Workflow builds image
# 3. Waits for manual approval
# 4. Reviewer approves in GitHub Actions UI
# 5. Image pushed to registry
```

**Advantages:**
- ✅ Maximum control
- ✅ Human verification before production
- ✅ Compliance-friendly
- ✅ Prevents accidental deployments

---

## 🔒 Current Workflow Configuration

### Environment Protection:
- **main branch** → `production` environment (requires approval)
- **dev branch** → `development` environment (auto-deploy)

### Security Gates:
1. ✅ Hadolint (Dockerfile linting)
2. ✅ Trivy vulnerability scanning
3. ✅ SBOM generation
4. ✅ GitHub Security alerts
5. ✅ Critical vulnerability warnings

### Image Tags:
- **SHA tag**: `ai-environment:abc123def` (always created)
- **latest tag**: `ai-environment:latest` (only on main)
- **dev tag**: `ai-environment:dev` (only on dev)

---

## 🎯 Recommended Strategy by Environment

### Development Environment:
```yaml
Approach: Direct Push or PR-based
Branch: dev
Auto-deploy: Yes
Approval: Not required
```

### Staging Environment:
```yaml
Approach: PR-based
Branch: staging (if exists)
Auto-deploy: Yes
Approval: Optional
```

### Production Environment:
```yaml
Approach: PR-based with Manual Approval
Branch: main
Auto-deploy: After approval
Approval: Required (1-2 reviewers)
```

---

## 🛠️ How to Push Changes Now

### Option 1: Direct to Main (Fast)
```bash
git add app/
git commit -m "Optimize Dockerfile with multi-stage build"
git push origin main
# ⚠️ Requires approval in GitHub Actions UI
```

### Option 2: Via Pull Request (Recommended)
```bash
git checkout -b feature/docker-optimization
git add app/
git commit -m "Optimize Dockerfile with multi-stage build"
git push origin feature/docker-optimization
# Create PR on GitHub → Review → Merge
```

### Option 3: Manual Trigger
```bash
# Go to GitHub Actions → Docker Build & Push → Run workflow
# Select branch and "Push image to registry: true"
```

---

## 📊 Workflow Outputs

After successful push, you'll get:
- 🐳 Image in GAR: `us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment`
- 📋 Security scan results in GitHub Security tab
- 📦 SBOM artifact for compliance
- 📝 Build summary in GitHub Actions

---

## 🔍 Monitoring & Verification

### Check if image was pushed:
```bash
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment
```

### Pull and test image:
```bash
docker pull us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:latest
docker run -p 8080:8080 us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:latest
```

---

## 🚨 Troubleshooting

### Image not pushed?
- Check if you're on `main` or `dev` branch
- Verify GitHub Actions completed successfully
- Check if approval is pending (for production)

### Security scan failed?
- Review Trivy results in GitHub Security tab
- Critical vulnerabilities show as warnings (don't block)
- Fix vulnerabilities and re-push

### Build failed?
- Check Hadolint results for Dockerfile issues
- Verify all required files exist (supervisord.conf, nginx.conf)
- Check build logs in GitHub Actions
