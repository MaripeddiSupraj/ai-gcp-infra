# Workload Identity Federation Module

This module sets up Workload Identity Federation for GitHub Actions, allowing GitHub workflows to authenticate with Google Cloud without using service account keys.

## Features

- Creates a Workload Identity Pool for GitHub Actions
- Configures OIDC provider for GitHub
- Creates a service account for GitHub Actions
- Grants specified IAM roles to the service account
- Binds the service account to a specific GitHub repository

## Usage

```hcl
module "github_actions_wi" {
  source = "../../modules/wi-federation"

  project_id                   = "my-gcp-project"
  pool_id                      = "github-actions-pool"
  pool_display_name            = "GitHub Actions Pool"
  provider_id                  = "github-actions-provider"
  provider_display_name        = "GitHub Actions Provider"
  service_account_id           = "github-actions-sa"
  service_account_display_name = "GitHub Actions Service Account"
  github_repository            = "owner/repo"
  project_iam_roles = [
    "roles/container.developer",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID | `string` | n/a | yes |
| pool_id | The ID of the Workload Identity Pool | `string` | n/a | yes |
| pool_display_name | The display name of the Workload Identity Pool | `string` | n/a | yes |
| provider_id | The ID of the Workload Identity Pool Provider | `string` | n/a | yes |
| provider_display_name | The display name of the Workload Identity Pool Provider | `string` | n/a | yes |
| service_account_id | The ID of the Service Account | `string` | n/a | yes |
| service_account_display_name | The display name of the Service Account | `string` | n/a | yes |
| project_iam_roles | The IAM roles to grant to the Service Account on the project | `list(string)` | `[]` | no |
| github_repository | The GitHub repository in the format 'owner/repo' | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| workload_identity_pool_id | The ID of the Workload Identity Pool for GitHub Actions authentication |
| workload_identity_pool_provider_id | The ID of the Workload Identity Pool Provider for GitHub Actions |
| service_account_email | The email address of the service account used by GitHub Actions |

## GitHub Actions Configuration

After creating the workload identity federation, configure your GitHub Actions workflow:

```yaml
name: Deploy

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v3

      - id: auth
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider'
          service_account: 'github-actions-sa@PROJECT_ID.iam.gserviceaccount.com'

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Deploy
        run: |
          gcloud container clusters get-credentials my-cluster --region us-central1
          kubectl apply -f k8s/
```

## Security Benefits

- **No Long-Lived Credentials**: No need to store service account keys in GitHub secrets
- **Short-Lived Tokens**: Tokens are automatically generated and expire quickly
- **Repository-Scoped**: Access is limited to the specified GitHub repository
- **Auditable**: All actions are logged and attributed to the service account

## Security Best Practices

- Use the principle of least privilege when assigning IAM roles
- Limit access to specific repositories using the `github_repository` variable
- Regularly audit service account permissions
- Monitor service account activity in Cloud Audit Logs
