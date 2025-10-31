.PHONY: plan apply destroy fmt validate

plan:
	@cd environments/dev && terraform plan

apply:
	@cd environments/dev && terraform apply

destroy:
	@cd environments/dev && terraform destroy

fmt:
	@terraform fmt -recursive

validate:
	@cd environments/dev && terraform validate

unlock:
	@cd environments/dev && terraform force-unlock -force $(LOCK_ID)
