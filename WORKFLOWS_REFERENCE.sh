#!/bin/bash
# WORKFLOW REFERENCE GUIDE

cat << 'EOF'

════════════════════════════════════════════════════════════════════════════════
                    🎯 WORKFLOW DECISION TREE
════════════════════════════════════════════════════════════════════════════════

┌─ TERRAFORM CHANGES (.tf files or modules/)
│
├─ IF: Creating Pull Request to main
│  └─ terraform.yml runs:
│     ├─ validate ✓
│     ├─ plan ✓
│     └─ Comment on PR with results
│     └─ NO APPLY (just for review)
│
├─ IF: Pushing/Merging to main
│  └─ terraform.yml runs:
│     ├─ validate ✓
│     ├─ plan ✓
│     ├─ approval-gate ⏸️ (WAIT for human approval)
│     └─ apply ✅ (only after approval)
│
└─ IF: Manual dispatch
   └─ Choose action: plan / apply / destroy
      └─ runs accordingly

───────────────────────────────────────────────────────────────────────────────

┌─ APPLICATION CHANGES (app/, requirements.txt, Dockerfile)
│
├─ IF: Creating Pull Request
│  └─ docker-build-push.yml runs:
│     ├─ security-scan ✓
│     ├─ build image ✓
│     ├─ scan image ✓
│     └─ NO PUSH (just validation)
│
├─ IF: Pushing to main or develop
│  └─ docker-build-push.yml runs:
│     ├─ security-scan ✓
│     ├─ build image ✓
│     ├─ scan image ✓
│     ├─ push to registry ✅
│     └─ auto-trigger ai-k8s-deploy.yml
│        ├─ pre-deployment checks ✓
│        ├─ deploy to K8s ✅
│        └─ health checks ✓
│
└─ IF: Manual dispatch
   └─ Choose: push_image = true/false

═══════════════════════════════════════════════════════════════════════════════

                        📋 ACTUAL WORKFLOWS

1. terraform.yml
   ├─ Triggers: .tf changes, modules/ changes, workflow_dispatch
   ├─ On PR: plan only
   ├─ On main push: plan + approval + apply
   ├─ Approval gate: Yes (production)
   └─ Auto K8s trigger: No

2. docker-build-push.yml
   ├─ Triggers: app/ changes, requirements.txt, Dockerfile
   ├─ On PR: build only
   ├─ On main push: build + push
   ├─ Security scan: Yes (Bandit + Safety)
   ├─ Container scan: Yes (Trivy)
   └─ Auto K8s trigger: Yes (after push)

3. ai-k8s-deploy.yml
   ├─ Triggers: manual dispatch, auto from docker build
   ├─ Pre-checks: Yes
   ├─ Rolling updates: Yes
   ├─ Rollback: Yes (via manual dispatch)
   ├─ Health checks: Yes
   └─ GPU support: Yes (prod only)

═══════════════════════════════════════════════════════════════════════════════

                    🎬 STEP-BY-STEP SCENARIOS

SCENARIO 1: Developer works on Terraform
────────────────────────────────────────────

Step 1: Create feature branch
  $ git checkout -b feature/add-monitoring
  
Step 2: Edit Terraform files
  $ vi modules/monitoring/main.tf
  
Step 3: Format and validate locally
  $ terraform fmt -recursive
  $ terraform validate
  $ terraform plan
  
Step 4: Push and create PR
  $ git add .
  $ git commit -m "Add monitoring alerts"
  $ git push origin feature/add-monitoring
  
  → Go to GitHub, create PR
  → terraform.yml automatically runs
  → Check PR comments for plan output
  → Review and approve/request changes
  
Step 5: Merge to main
  $ Merge PR on GitHub
  
  → terraform.yml runs again
  → Creates plan
  → Waits for approval ⏸️
  → Merge initiator can approve via GitHub Actions environment
  → terraform apply runs ✅


SCENARIO 2: Developer updates application
──────────────────────────────────────────

Step 1: Create feature branch
  $ git checkout -b feature/new-api-endpoint
  
Step 2: Update app code
  $ vi app/app.py
  $ vi requirements.txt
  
Step 3: Commit and push to feature branch
  $ git add .
  $ git commit -m "Add new endpoint"
  $ git push origin feature/new-api-endpoint
  
  → Create PR on GitHub
  → docker-build-push.yml runs
  → Builds image (no push)
  → Runs security scans
  → PR gets check status
  
Step 4: Merge to main
  → docker-build-push.yml runs again
  → Builds image
  → Runs security scans
  → Pushes to Artifact Registry ✅
  → Auto-triggers ai-k8s-deploy.yml
    └─ Deploys to Kubernetes ✅


SCENARIO 3: Combined changes
────────────────────────────

Step 1: Update both app AND Terraform
  $ git checkout -b feature/scale-and-update
  $ vi app/app.py (app changes)
  $ vi modules/gke/main.tf (infra changes)
  $ git add .
  $ git push origin feature/scale-and-update
  
Step 2: Create PR
  → Both terraform.yml and docker-build-push.yml trigger
  → Both run validation
  → Both show results on PR
  
Step 3: Merge to main
  → Both workflows trigger
  → terraform.yml: validates → plans → waits for approval ⏸️
  → docker-build-push.yml: builds → scans → pushes ✅
  → Once approved, terraform applies ✅
  → K8s deployment auto-triggers ✅
  → Everything updates!

═══════════════════════════════════════════════════════════════════════════════

                    ⏱️ TYPICAL EXECUTION TIMES

Terraform Workflow:
  ├─ Validate: 1-2 min
  ├─ Plan: 3-5 min
  ├─ Approval gate: ⏸️ (manual, can be hours)
  └─ Apply: 5-15 min
  ─────────────────
  Total: 10-25 min (+ approval wait)

Docker Workflow:
  ├─ Security Scan: 1-2 min
  ├─ Build: 3-5 min
  ├─ Image Scan: 2-3 min
  ├─ Push: 1-2 min
  └─ K8s Auto-Trigger
  ─────────────────
  Total: 8-13 min

Combined (both changes):
  Both run in parallel, so total = max(terraform, docker) + approval wait

═══════════════════════════════════════════════════════════════════════════════

                    📊 APPROVAL GATES EXPLAINED

For Terraform:
  ✓ Approval gate ONLY on main branch
  ✓ Approval gate ONLY if changes detected
  ✓ Can be approved by repo maintainers
  ✓ Go to: Actions → Run → Environment approval
  ✓ Or: Approve via GitHub Actions UI

For Docker/K8s:
  ✓ No approval gate (automatic if validated)
  ✓ Just review in real-time if needed
  ✓ Can rollback afterward if issues

═══════════════════════════════════════════════════════════════════════════════

                    🔒 SAFETY MECHANISMS

Terraform:
  ✓ PR = plan only (no apply)
  ✓ Main push = approval required
  ✓ Plan checksums = prevent tampering
  ✓ Concurrency lock = no parallel applies

Docker:
  ✓ PR = build only (no push)
  ✓ Main/develop = push allowed
  ✓ Security scans before build
  ✓ Container scans before push

Kubernetes:
  ✓ Pre-deployment validation
  ✓ Health checks
  ✓ Rollback available
  ✓ Rolling updates (zero downtime)

═══════════════════════════════════════════════════════════════════════════════

                    💡 BEST PRACTICES

1. Always create PR before main
   ✓ Allows for review
   ✓ Runs automatic checks
   ✓ Documents changes

2. Review plan before approving
   ✓ Prevents accidental changes
   ✓ Catches issues early

3. Don't force-push to main
   ✓ Breaks audit trail
   ✓ Bypasses checks

4. Use meaningful commit messages
   ✓ Helps with history
   ✓ Useful for reviews

5. Test locally first
   ✓ Catch obvious issues
   ✓ Faster feedback loop

═══════════════════════════════════════════════════════════════════════════════

                    🐛 TROUBLESHOOTING

If terraform.yml doesn't trigger:
  1. Check paths: did you modify .tf files?
  2. Check branch: did you push to main or create PR?
  3. Check workflow file: is it valid YAML?

If docker-build-push.yml doesn't trigger:
  1. Check paths: did you modify app/ files?
  2. Check branch: did you push to main/develop?
  3. Check GCP credentials: is GCP_SA_KEY valid?

If K8s deployment doesn't start:
  1. Check docker build succeeded
  2. Check image was pushed to registry
  3. Check k8s-deploy.yml is valid

═══════════════════════════════════════════════════════════════════════════════

                    ✅ READY TO USE!

Your workflows are production-ready and follow best practices:
  ✓ PR validation before merging
  ✓ Approval gates for production
  ✓ Automatic security scanning
  ✓ Plan checksums for safety
  ✓ Auto-triggered deployments
  ✓ Zero-downtime updates

Start with small changes and build confidence!

═══════════════════════════════════════════════════════════════════════════════
EOF
