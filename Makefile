.PHONY: help setup check-prerequisites

help:
	@cat $(firstword $(MAKEFILE_LIST))

setup: \
	check-prerequisites \
	check-version

check-prerequisites:
	type tfenv

check-version:
	terraform --version
