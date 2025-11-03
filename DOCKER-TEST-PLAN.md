# Docker Workflow Test Plan

## 🧪 Test Scenarios

### Scenario 1: Local Docker Build Test
**Purpose:** Verify Dockerfile builds successfully locally

```bash
cd /Users/maripeddisupraj/Desktop/ai-gcp-infra/app

# Test 1: Build the image
docker build -t ai-environment:test .

# Expected: Build completes without errors
# Check for: All stages complete, no missing files

# Test 2: Check image size
docker images ai-environment:test

# Expected: Image size ~1.5-2GB (optimized with multi-stage)

# Test 3: Inspect image layers
docker history ai-environment:test

# Expected: See 4 build stages (python-builder, node-builder, vscode-builder, final)
```

---

### Scenario 2: Local Container Run Test
**Purpose:** Verify container starts and services run

```bash
# Test 1: Run container
docker run -d --name ai-test -p 8080:8080 -p 8001:8001 -p 1111:1111 ai-environment:test

# Test 2: Check container logs
docker logs ai-test

# Expected: See supervisor starting all services (mongodb, nginx, code-server, app)

# Test 3: Check running processes
docker exec ai-test ps aux

# Expected: See mongod, nginx, code-server, gunicorn processes

# Test 4: Test health endpoints
curl http://localhost:8001/health
curl http://localhost:8080

# Expected: HTTP 200 responses

# Test 5: Check nginx proxy
curl http://localhost:1111

# Expected: Nginx routes to VSCode

# Cleanup
docker stop ai-test
docker rm ai-test
```

---

### Scenario 3: Dockerfile Linting Test
**Purpose:** Verify Dockerfile follows best practices

```bash
# Install hadolint (if not installed)
brew install hadolint  # macOS
# or
docker pull hadolint/hadolint

# Test: Run hadolint
hadolint app/Dockerfile

# Expected: No errors, warnings acceptable
# or using Docker:
docker run --rm -i hadolint/hadolint < app/Dockerfile
```

---

### Scenario 4: Security Scan Test (Local)
**Purpose:** Check for vulnerabilities before pushing

```bash
# Install trivy (if not installed)
brew install aquasecurity/trivy/trivy  # macOS

# Test 1: Scan for vulnerabilities
trivy image ai-environment:test

# Expected: Report of vulnerabilities (if any)

# Test 2: Check for critical vulnerabilities only
trivy image --severity CRITICAL ai-environment:test

# Expected: List critical issues (should be minimal)

# Test 3: Generate SBOM
trivy image --format spdx-json -o sbom.json ai-environment:test

# Expected: SBOM file created
```

---

### Scenario 5: Pull Request Workflow Test
**Purpose:** Verify PR triggers build and scan only (no push)

```bash
# Step 1: Create feature branch
git checkout -b test/docker-optimization

# Step 2: Make a small change (to trigger workflow)
echo "# Test change" >> app/README.md
git add app/README.md
git commit -m "test: trigger docker workflow"

# Step 3: Push to feature branch
git push origin test/docker-optimization

# Step 4: Create PR on GitHub
# Go to: https://github.com/YOUR_REPO/pull/new/test/docker-optimization

# Expected Results:
# ✅ Security scan job runs
# ✅ Build job runs
# ✅ Trivy scan completes
# ✅ SBOM generated
# ❌ Image NOT pushed to registry
# ✅ Security results visible in PR

# Step 5: Check GitHub Actions
# Go to: Actions tab → Docker Build & Push workflow

# Step 6: Verify no push occurred
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment

# Expected: No new image with test branch SHA
```

---

### Scenario 6: Dev Branch Push Test
**Purpose:** Verify push to dev branch triggers build and push

```bash
# Step 1: Switch to dev branch
git checkout dev

# Step 2: Merge or make changes
git merge test/docker-optimization
# or make direct changes

# Step 3: Push to dev
git push origin dev

# Expected Results:
# ✅ Security scan runs
# ✅ Build completes
# ✅ Trivy scan passes
# ✅ Image pushed with tags: SHORT_SHA + 'dev'
# ✅ No manual approval required

# Step 4: Verify image in registry
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment \
  --filter="tags:dev"

# Expected: See image with 'dev' tag

# Step 5: Pull and test image
docker pull us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:dev
docker run -d --name test-dev -p 8080:8080 \
  us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:dev

# Cleanup
docker stop test-dev && docker rm test-dev
```

---

### Scenario 7: Main Branch Push Test (Production)
**Purpose:** Verify push to main requires approval and pushes with 'latest' tag

```bash
# Step 1: Merge PR to main (or push directly)
git checkout main
git merge test/docker-optimization
git push origin main

# Expected Results:
# ✅ Security scan runs
# ✅ Build completes
# ✅ Trivy scan passes
# ⏸️ Workflow WAITS for manual approval (production environment)

# Step 2: Approve deployment
# Go to: GitHub Actions → Running workflow → Review deployments → Approve

# After Approval:
# ✅ Image pushed with tags: SHORT_SHA + 'latest'

# Step 3: Verify images in registry
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment

# Expected: See two tags for same image:
# - ai-environment:abc123d (7-char SHA)
# - ai-environment:latest

# Step 4: Verify tags point to same image
gcloud artifacts docker images describe \
  us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:latest

gcloud artifacts docker images describe \
  us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:abc123d

# Expected: Same image digest

# Step 5: Pull and test
docker pull us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:latest
docker run -d --name test-prod -p 8080:8080 \
  us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:latest

# Cleanup
docker stop test-prod && docker rm test-prod
```

---

### Scenario 8: Manual Workflow Dispatch Test
**Purpose:** Verify manual trigger works

```bash
# Step 1: Go to GitHub Actions
# Navigate to: Actions → Docker Build & Push → Run workflow

# Step 2: Select options
# - Branch: main or dev
# - Push image to registry: true

# Step 3: Run workflow

# Expected Results:
# ✅ Workflow runs on selected branch
# ✅ If 'true' selected, image pushed
# ✅ If 'false' selected, only build and scan

# Step 4: Verify in registry (if pushed)
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment
```

---

### Scenario 9: Concurrent Build Test
**Purpose:** Verify concurrency control works

```bash
# Step 1: Make two quick commits to dev
echo "change1" >> app/test1.txt
git add app/test1.txt
git commit -m "test: concurrent 1"
git push origin dev

# Immediately after:
echo "change2" >> app/test2.txt
git add app/test2.txt
git commit -m "test: concurrent 2"
git push origin dev

# Expected Results:
# ✅ First workflow starts
# ✅ Second workflow cancels first (cancel-in-progress: true)
# ✅ Only second workflow completes
# ✅ Only one image pushed (latest commit)

# Verify in GitHub Actions:
# - First workflow shows "Cancelled"
# - Second workflow shows "Success"
```

---

### Scenario 10: Security Vulnerability Test
**Purpose:** Verify workflow handles vulnerabilities correctly

```bash
# This is informational - workflow will warn but not block

# Expected Behavior:
# ✅ Trivy scan runs
# ✅ Vulnerabilities reported in GitHub Security tab
# ⚠️ Critical vulnerabilities show warning
# ✅ Build continues (doesn't fail)
# ✅ Image still pushed (with warning)

# Check security findings:
# Go to: GitHub → Security → Code scanning alerts
```

---

## 📊 Test Results Checklist

### Local Tests:
- [ ] Dockerfile builds successfully
- [ ] Multi-stage build reduces image size
- [ ] Container starts without errors
- [ ] All services running (mongodb, nginx, code-server, app)
- [ ] Health endpoints respond
- [ ] Hadolint passes
- [ ] Trivy scan completes

### GitHub Actions Tests:
- [ ] PR triggers build only (no push)
- [ ] Dev push triggers auto-deploy
- [ ] Main push requires approval
- [ ] Manual trigger works
- [ ] Concurrency control works
- [ ] Security scans upload to GitHub Security
- [ ] SBOM artifacts uploaded

### Registry Tests:
- [ ] Images pushed with correct tags
- [ ] Short SHA (7 chars) used
- [ ] 'latest' tag on main branch
- [ ] 'dev' tag on dev branch
- [ ] Images pullable from registry
- [ ] Tags point to correct images

### Integration Tests:
- [ ] Pulled image runs successfully
- [ ] All services accessible
- [ ] VSCode Server works
- [ ] Flask app responds
- [ ] MongoDB accessible
- [ ] Nginx proxy routes correctly

---

## 🚨 Troubleshooting

### Build Fails:
```bash
# Check logs
docker build --progress=plain -t ai-environment:test app/

# Check for missing files
ls -la app/
```

### Container Won't Start:
```bash
# Check logs
docker logs ai-test

# Check supervisor status
docker exec ai-test supervisorctl status
```

### Workflow Fails:
```bash
# Check GitHub Actions logs
# Look for specific step that failed
# Common issues:
# - Missing secrets (GCP_SA_KEY)
# - Permission issues
# - Registry authentication
```

### Image Not in Registry:
```bash
# Verify authentication
gcloud auth list
gcloud config get-value project

# Check if workflow completed
# Check if approval was given (for main branch)
```

---

## ✅ Success Criteria

All tests pass when:
1. ✅ Dockerfile builds locally without errors
2. ✅ Container runs and all services start
3. ✅ PR workflow builds but doesn't push
4. ✅ Dev branch auto-deploys
5. ✅ Main branch requires approval
6. ✅ Images tagged with 7-char SHA
7. ✅ Security scans complete
8. ✅ Images pullable from registry
9. ✅ Pulled images run successfully
10. ✅ No critical security issues blocking deployment
