# Contributing Guidelines

## Terraform Workflow Rules

### ❌ DO NOT Run Locally:
```bash
# NEVER run these commands locally:
terraform apply
terraform destroy
```

### ✅ Correct Workflow:

1. **Make Changes**:
   ```bash
   git checkout -b feature/my-change
   # Edit terraform files
   terraform fmt
   terraform validate
   ```

2. **Create PR**:
   ```bash
   git add .
   git commit -m "Add: description"
   git push origin feature/my-change
   # Open PR on GitHub
   ```

3. **Review Plan**:
   - GitHub Actions automatically runs `terraform plan`
   - Plan output posted as PR comment
   - Review changes with team

4. **Merge PR**:
   - After approval, merge to main
   - Plan runs again on main (validation)

5. **Deploy** (Authorized users only):
   - Go to: Actions → Terraform CI/CD → Run workflow
   - Select: `action=apply`, `environment=dev`
   - Click "Run workflow"

## Why This Matters

- **Single Source of Truth**: All changes go through GitHub
- **Audit Trail**: Every change is tracked in Git + GitHub Actions
- **No Drift**: State is managed centrally
- **Team Visibility**: Everyone sees what's being deployed
- **Rollback**: Easy to revert via Git

## Local Development

You can run these locally for testing:
```bash
terraform fmt
terraform validate
terraform plan  # Read-only, safe
```

But **NEVER** run `apply` or `destroy` locally.
