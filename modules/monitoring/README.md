# Monitoring Module

This module creates Google Cloud Monitoring resources including alert policies and notification channels for GKE clusters.

## Features

- Email notification channel for alerts
- Pre-configured alert policies for common issues:
  - High pod restart rate
  - High node CPU usage
  - Spot instance preemption

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project_id  = "my-gcp-project"
  alert_email = "team@example.com"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID where monitoring resources will be created | `string` | n/a | yes |
| alert_email | Email address to receive monitoring alerts and notifications | `string` | `"alerts@example.com"` | no |

## Outputs

| Name | Description |
|------|-------------|
| notification_channel_id | The ID of the monitoring notification channel for email alerts |

## Alert Policies

### High Pod Restart Rate
- **Threshold**: More than 5 restarts in 5 minutes
- **Purpose**: Detect pods that are crashing or unhealthy
- **Action**: Investigate pod logs and health checks

### High Node CPU Usage
- **Threshold**: Node CPU utilization > 80% for 5 minutes
- **Purpose**: Detect potential capacity issues
- **Action**: Consider scaling up nodes or optimizing workloads

### Spot Instance Preemption
- **Threshold**: Spot node preempted
- **Purpose**: Track spot instance interruptions
- **Action**: Ensure workloads are resilient to preemption

## Best Practices

- Use a distribution list for `alert_email` to ensure alerts reach the right team
- Regularly review and tune alert thresholds based on your workload patterns
- Set up runbooks for each alert type to guide response actions
- Consider integrating with incident management tools (PagerDuty, Opsgenie, etc.)
