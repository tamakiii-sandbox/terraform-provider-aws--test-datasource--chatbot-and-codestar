.PHONY: help check

help:
	@cat $(firstword $(MAKEFILE_LIST))

check:
	type tfenv

plan:
	terraform plan
