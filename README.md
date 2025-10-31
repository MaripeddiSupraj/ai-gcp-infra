# ai-gcp-infra

Production-grade GCP infrastructure with Terraform and Kubernetes.

## Quick Start

```bash
# Format and validate
make fmt
make validate

# Plan changes
make plan

# Apply (with approval)
make apply

# If state locked
make unlock LOCK_ID=<lock-id-from-error>
```

## Structure

```
environments/dev/     # Dev environment
modules/              # Reusable modules
.github/workflows/    # CI/CD pipelines
```

## Workflows

- **Docker**: Build, scan, push on app changes
- **Terraform**: Plan on PR, apply on main (requires approval)

## Cost

- Spot nodes: ~$25/month per node (default)
- On-demand: ~$75/month per node (critical only)
- Total: ~$125-575/month

## State Lock Prevention

✅ **Already fixed:**
- GitHub Actions: Concurrency control prevents simultaneous runs
- Local: Use `make plan/apply` commands (handles cleanup)

**If locked:** `make unlock LOCK_ID=<id>`
