#!/bin/bash
# Cleanup unused files from repository

echo "🗑️  Removing unused files..."

# Remove future architecture docs (not current implementation)
rm -f ARCHITECTURE.md
rm -f TESTING-PLAN.md
rm -f image.png

# Remove duplicate tfvars
rm -f environments/dev/terraform.auto.tfvars

# Remove .terraform directories (build artifacts)
find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true

echo "✅ Cleanup complete!"
echo ""
echo "Files kept:"
echo "  ✅ All Terraform modules (in use)"
echo "  ✅ K8s manifests (deployed)"
echo "  ✅ App code (deployed)"
echo "  ✅ CI/CD workflows (active)"
echo "  ✅ README.md, SECURITY.md (documentation)"
echo "  ✅ INFRASTRUCTURE-VERIFICATION.md (client checklist)"
echo "  ✅ Makefile, .gitignore (tooling)"
