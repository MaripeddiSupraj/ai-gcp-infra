#!/bin/bash
# Cleanup unnecessary files from the project

echo "Removing unnecessary files..."

# Root-level Terraform files (GHA uses environments/dev/ instead)
rm -f main.tf variables.tf outputs.tf terraform.tfvars .terraform.lock.hcl
rm -rf .terraform/

# Unused K8s manifests
rm -rf k8s-manifests/base/
rm -rf k8s-manifests/ingress/
rm -rf k8s-manifests/monitoring/
rm -rf k8s-manifests/network-policies/
rm -rf k8s-manifests/overlays/
rm -rf k8s-manifests/security/
rm -f k8s-manifests/deployment-critical.yaml
rm -f k8s-manifests/deployment.yaml
rm -f k8s-manifests/hpa.yaml
rm -f k8s-manifests/namespace-dev.yaml
rm -f k8s-manifests/namespace-prod.yaml
rm -f k8s-manifests/pod-disruption-budget.yaml
rm -f k8s-manifests/priority-classes.yaml
rm -f k8s-manifests/service.yaml

# K8s examples
rm -rf k8s-examples/

# Unused modules
rm -rf modules/load-balancer/
rm -rf modules/monitoring/
rm -rf modules/gke-autopilot/

# Unused config files
rm -f .pre-commit-config.yaml
rm -f .tflint.hcl
rm -f .tfsec.yml

# Extra docs
rm -f CONTRIBUTING.md
rm -f terraform.tfvars.example

echo "Cleanup complete!"
echo ""
echo "Files kept:"
echo "  - environments/dev/ (active Terraform)"
echo "  - modules/ (network, gke, gar, security, wi-federation)"
echo "  - app/ (Docker application)"
echo "  - k8s-manifests/ai-app-deployment.yaml (active deployment)"
echo "  - .github/workflows/ (CI/CD)"
echo "  - README.md, SECURITY.md, Makefile, .gitignore"
