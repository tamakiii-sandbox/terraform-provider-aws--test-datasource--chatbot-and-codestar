.PHONY: help setup teardown check-prerequisites

help:
	@cat $(firstword $(MAKEFILE_LIST))

setup: \
	check-prerequisites

teardown:
	rm -rf bin/terraform

check-prerequisites:
	type tfenv
