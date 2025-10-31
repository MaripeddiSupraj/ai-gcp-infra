.PHONY: plan apply destroy fmt validate

plan:
	@echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  TERRAFORM PLAN"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	@cd environments/dev && terraform plan -no-color -compact-warnings -lock-timeout=5m
	@echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  PLAN COMPLETE"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

apply:
	@cd environments/dev && terraform apply -no-color -lock-timeout=5m

destroy:
	@cd environments/dev && terraform destroy -no-color -lock-timeout=5m -auto-approve

fmt:
	@terraform fmt -recursive

validate:
	@cd environments/dev && terraform validate

unlock:
	@cd environments/dev && terraform force-unlock -force $(LOCK_ID)

force-unlock:
	@echo "Checking for stale locks..."
	@cd environments/dev && terraform force-unlock -force 1761909226701536 2>/dev/null || true
