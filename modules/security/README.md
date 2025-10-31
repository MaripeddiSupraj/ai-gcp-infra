# Workload Identity (Security) Module

This module sets up Workload Identity for GKE, allowing Kubernetes pods to authenticate as Google Cloud service accounts.

## Features

- Creates a Google Cloud service account
- Configures Workload Identity binding between Kubernetes and GCP service accounts
- Grants specified IAM roles to the service account
- Follows security best practices for GKE workload authentication

## Usage

```hcl
module "workload_identity" {
  source = "../../modules/security"

  project_id           = "my-gcp-project"
  service_account_name = "app-workload-identity"
  namespace            = "default"
  k8s_service_account  = "app-sa"
  iam_roles = [
    "roles/storage.objectViewer",
    "roles/cloudtrace.agent"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID where the workload identity service account will be created | `string` | n/a | yes |
| service_account_name | The name (account_id) of the service account for workload identity | `string` | n/a | yes |
| namespace | The Kubernetes namespace where the workload identity will be used | `string` | n/a | yes |
| k8s_service_account | The name of the Kubernetes service account to bind with GCP service account | `string` | n/a | yes |
| iam_roles | List of IAM roles to grant to the workload identity service account | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| service_account_email | The email address of the workload identity service account |
| service_account_name | The fully-qualified name of the workload identity service account |

## Kubernetes Configuration

After creating the workload identity, configure your Kubernetes service account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: default
  annotations:
    iam.gke.io/gcp-service-account: app-workload-identity@my-project.iam.gserviceaccount.com
```

And reference it in your pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: default
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: my-image
```

## Security Best Practices

- Use the principle of least privilege when assigning IAM roles
- Create separate service accounts for different applications
- Use namespace isolation to limit the scope of service accounts
- Regularly review and audit IAM role assignments
