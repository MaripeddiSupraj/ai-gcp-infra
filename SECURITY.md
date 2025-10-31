# Security Considerations

This document outlines security considerations and decisions made in this Terraform infrastructure.

## Implemented Security Features

### Network Security
- ✅ **VPC Flow Logs**: Enabled on all subnets with 50% sampling rate for network monitoring and security auditing
- ✅ **Private Google Access**: Enabled for secure access to Google Cloud APIs without public IPs

### GKE Cluster Security
- ✅ **Workload Identity**: Enabled on both standard and autopilot clusters for secure pod authentication
- ✅ **Binary Authorization**: Enabled for deployment policy enforcement
- ✅ **Shielded Nodes**: Enabled with secure boot and integrity monitoring
- ✅ **Network Policy**: Enabled in standard GKE for pod-to-pod network isolation
- ✅ **GKE Metadata Server**: Enabled, legacy endpoints disabled at node level
- ✅ **Managed Prometheus**: Enabled for security monitoring
- ✅ **Security Posture**: Basic security posture with vulnerability scanning

### Node Pool Security
- ✅ **COS_CONTAINERD**: Container-Optimized OS with containerd runtime
- ✅ **Auto-upgrade**: Enabled for automatic security patches
- ✅ **Auto-repair**: Enabled for automatic node health management

### Authentication & Authorization
- ✅ **Workload Identity Federation**: Implemented for GitHub Actions (keyless authentication)
- ✅ **IAM Roles**: Granular IAM role assignments following least privilege principle

## Optional Security Hardening

The following security features are not enabled by default but can be configured based on your security requirements:

### Pod Security Standards (PSS)
**Status**: Not implemented (replaced Pod Security Policy which is deprecated in Kubernetes 1.25+)

**Recommendation**: Implement Pod Security Standards using admission controllers:
```yaml
# Example: Enforce restricted pod security standard
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Master Authorized Networks
**Status**: Not enabled by default (allows access from all IPs)

**Recommendation**: Enable for production clusters to restrict Kubernetes API access:
```hcl
# In GKE module
master_authorized_networks_config {
  cidr_blocks {
    cidr_block   = "10.0.0.0/8"
    display_name = "Internal network"
  }
  cidr_blocks {
    cidr_block   = "1.2.3.4/32"
    display_name = "Office IP"
  }
}
```

### Private GKE Cluster
**Status**: Not enabled by default (nodes have public IPs)

**Recommendation**: Enable for production clusters for enhanced isolation:
```hcl
# In GKE module
private_cluster_config {
  enable_private_nodes    = true
  enable_private_endpoint = false  # Set to true for fully private
  master_ipv4_cidr_block  = "172.16.0.0/28"
}
```

**Trade-offs**:
- Requires Cloud NAT for internet access from nodes
- May require bastion host or VPN for kubectl access if endpoint is private
- Increases infrastructure complexity

### Custom Node Service Accounts
**Status**: Using default Compute Engine service account

**Recommendation**: Create custom service accounts with minimal permissions:
```hcl
resource "google_service_account" "gke_nodes" {
  account_id   = "gke-node-sa"
  display_name = "GKE Node Service Account"
}

resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/stackdriver.resourceMetadata.writer"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}
```

## Security Scanning

This repository uses:
- **tfsec**: Static analysis security scanner for Terraform
- **tflint**: Linter to catch common Terraform issues

Run security scans locally:
```bash
# Run tfsec
tfsec modules/

# Run tflint
tflint --recursive
```

## Security Best Practices

1. **Secrets Management**
   - Never commit secrets or credentials to version control
   - Use Google Secret Manager for sensitive data
   - Use Workload Identity instead of service account keys

2. **IAM**
   - Follow principle of least privilege
   - Regularly audit IAM permissions
   - Use service accounts with specific roles instead of Owner/Editor

3. **Network Security**
   - Use private clusters for production workloads
   - Implement master authorized networks
   - Use Cloud Armor for DDoS protection if using load balancers

4. **Monitoring & Auditing**
   - Enable Cloud Audit Logs
   - Configure alerting for security events
   - Regularly review Cloud Logging for suspicious activity

5. **Compliance**
   - Review GKE hardening guide: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster
   - Consider CIS Kubernetes Benchmark for additional hardening
   - Enable Binary Authorization for supply chain security

## Known Security Findings

### tfsec Findings Not Addressed

The following tfsec findings are acknowledged but not addressed for the following reasons:

1. **google-gke-enforce-pod-security-policy** (HIGH)
   - Pod Security Policy is deprecated in Kubernetes 1.25+
   - Replaced by Pod Security Standards (PSS) which are configured via admission controllers
   - **Action**: Implement PSS in your namespace configurations

2. **google-gke-metadata-endpoints-disabled** (HIGH)
   - Legacy metadata endpoints are disabled at the node level (metadata.disable-legacy-endpoints = "true")
   - tfsec flags this at cluster level for autopilot where it's managed by Google
   - **Status**: Mitigated

3. **google-gke-enable-master-networks** (HIGH)
   - Master authorized networks is optional and should be enabled for production
   - Not enabled by default to allow flexibility during development
   - **Action**: Enable in production environments

4. **google-gke-use-service-account** (MEDIUM)
   - Using default Compute Engine service account is common practice
   - Can be customized if stricter IAM controls are required
   - **Action**: Create custom service accounts if needed

5. **google-gke-enable-private-cluster** (MEDIUM)
   - Private clusters are optional and add complexity
   - Should be enabled for production environments handling sensitive data
   - **Action**: Enable in production environments

## Regular Security Reviews

Schedule regular security reviews to:
- Review and rotate service account keys (if any)
- Audit IAM permissions
- Update dependencies and Terraform providers
- Review Cloud Audit Logs
- Test disaster recovery procedures
- Review and update alert configurations
