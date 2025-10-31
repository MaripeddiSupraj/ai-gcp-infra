# Google Artifact Registry Module

This module creates a Google Artifact Registry repository for storing container images and other artifacts.

## Features

- Support for multiple artifact formats (Docker, Maven, npm, Python, etc.)
- Regional repository for low-latency access
- Format validation to ensure correct repository type

## Usage

```hcl
module "gar" {
  source = "../../modules/gar"

  project_id    = "my-gcp-project"
  repository_id = "docker-repo"
  region        = "us-central1"
  format        = "DOCKER"
  description   = "Docker repository for container images"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID where the Artifact Registry repository will be created | `string` | n/a | yes |
| repository_id | The ID of the Artifact Registry repository | `string` | n/a | yes |
| region | The GCP region where the repository will be created | `string` | n/a | yes |
| format | The format of the repository | `string` | `"DOCKER"` | no |
| description | A description for the Artifact Registry repository | `string` | `"Docker repository"` | no |

## Outputs

| Name | Description |
|------|-------------|
| repository_id | The ID of the Artifact Registry repository |
| repository_url | The full URL to use for pushing images to the Artifact Registry repository |

## Supported Formats

- DOCKER
- MAVEN
- NPM
- PYTHON
- APT
- YUM
- GO
- KFP

## Example: Pushing Docker Images

```bash
# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Tag your image
docker tag my-image:latest us-central1-docker.pkg.dev/my-project/docker-repo/my-image:latest

# Push to Artifact Registry
docker push us-central1-docker.pkg.dev/my-project/docker-repo/my-image:latest
```
