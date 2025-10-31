# Load Balancer Module

This module creates a Google Cloud HTTP(S) Load Balancer for routing traffic to GKE services.

## Features

- Global load balancing with Cloud Load Balancer
- Optional managed SSL certificates
- Optional Cloud CDN for content caching
- Health checks for backend monitoring
- Logging enabled for troubleshooting
- HTTP and HTTPS support

## Usage

```hcl
module "load_balancer" {
  source = "../../modules/load-balancer"

  project_id = "my-gcp-project"
  lb_name    = "my-app-lb"
  neg_id     = "projects/my-project/zones/us-central1-a/networkEndpointGroups/my-neg"
  enable_ssl = true
  enable_cdn = true
  domains    = ["example.com", "www.example.com"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID where the load balancer will be created | `string` | n/a | yes |
| lb_name | The name prefix for the load balancer resources | `string` | n/a | yes |
| neg_id | Network Endpoint Group ID from GKE to use as backend | `string` | n/a | yes |
| enable_ssl | Whether to enable SSL/HTTPS with managed certificate | `bool` | `false` | no |
| enable_cdn | Whether to enable Cloud CDN for content caching | `bool` | `true` | no |
| domains | List of domains for the managed SSL certificate | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| global_ip | The global IP address allocated for the load balancer |
| url_map_id | The ID of the URL map resource |
| backend_service_id | The ID of the backend service |

## Components Created

1. **Global IP Address**: Static IP for the load balancer
2. **Backend Service**: Routes traffic to the Network Endpoint Group
3. **Health Check**: Monitors backend health (HTTP on port 8080, path /health)
4. **URL Map**: Routes requests to the backend service
5. **HTTP Proxy**: Handles HTTP traffic
6. **HTTPS Proxy** (optional): Handles HTTPS traffic with SSL certificate
7. **Managed SSL Certificate** (optional): Automatic SSL certificate provisioning
8. **Forwarding Rules**: Routes incoming traffic to the appropriate proxy

## Health Check Configuration

The default health check configuration:
- **Port**: 8080
- **Path**: /health
- **Check Interval**: 10 seconds
- **Timeout**: 5 seconds
- **Healthy Threshold**: 2 consecutive successes
- **Unhealthy Threshold**: 3 consecutive failures

Ensure your application exposes a health endpoint at `/health` on port 8080.

## SSL Certificate Provisioning

When `enable_ssl = true`, a managed SSL certificate is automatically provisioned for the specified domains. Note:
- Domain verification can take up to 24 hours
- Ensure DNS is properly configured before enabling SSL
- The certificate is automatically renewed by Google

## Cloud CDN

When `enable_cdn = true`, Cloud CDN caches content at Google's edge locations for:
- Reduced latency for users
- Lower egress costs
- Better performance for static content

## Example: DNS Configuration

After deployment, configure your DNS to point to the load balancer IP:

```
A    example.com        -> <load_balancer_ip>
A    www.example.com    -> <load_balancer_ip>
```
