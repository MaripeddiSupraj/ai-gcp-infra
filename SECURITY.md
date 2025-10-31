# Security Policy

## Infrastructure Security

### Secrets Management
- **GCP Service Account Keys**: Stored in GitHub Secrets (`GCP_SA_KEY`)
- **Terraform State**: Encrypted at rest in GCS bucket
- **Workload Identity**: Used instead of service account keys in pods

### Access Control
- **Terraform Apply**: Requires manual approval via GitHub environment protection
- **GKE Access**: RBAC enabled with least privilege principle
- **Network Policies**: Default deny with explicit allow rules

### Monitoring
- **Drift Detection**: Automated daily checks for infrastructure changes
- **Security Scanning**: Weekly scans with Trivy, Checkov, tfsec
- **Alerts**: Configured for pod restarts, CPU usage, spot preemptions

## Reporting a Vulnerability

If you discover a security vulnerability, please email: supraj.maripeddi@gmail.com

**Do not** create a public GitHub issue for security vulnerabilities.

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Review Terraform plans** before applying
3. **Monitor drift detection** alerts
4. **Keep dependencies updated** (Terraform, providers, actions)
5. **Use Workload Identity** for GCP access from pods
6. **Enable audit logging** in GCP Console
7. **Regularly review IAM permissions**

## Compliance

- Pod Security Standards: Baseline (default), Restricted (prod)
- Network Policies: Zero-trust model
- Binary Authorization: Enabled
- Shielded Nodes: Enabled
- Workload Identity: Enabled
