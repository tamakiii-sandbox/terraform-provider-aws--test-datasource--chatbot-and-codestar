.PHONY: help check init plan clean

export AWS_REGION
export S3_BUCKET
export DIRECTORY

help:
	@cat $(firstword $(MAKEFILE_LIST))

check:
	type tfenv

init: state.config
	terraform init -backend-config="$<"

plan: \
	tfplan

clean:
	rm tfplan

apply:
	terraform apply tfplan

tfplan:
	terraform plan -out $@

state.config: state.template.config
	export COMMENT="This file was created by Makefile" && envsubst < $< > $@
