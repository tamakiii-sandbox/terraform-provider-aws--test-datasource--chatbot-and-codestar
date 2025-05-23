.PHONY: help setup teardown

VERSION := 1.12.1
OS := $(shell uname -s | tr A-Z a-z)
ARCH := $(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

help:
	@cat $(firstword $(MAKEFILE_LIST))

setup: \
	bin \
	bin/terraform

teardown:
	rm -rf bin/terraform

bin:
	mkdir -p $@

bin/terraform:
	curl -sL "https://releases.hashicorp.com/terraform/$(VERSION)/terraform_$(VERSION)_$(OS)_$(ARCH).zip" > /tmp/tf.zip
	unzip -p /tmp/tf.zip terraform > $@ && rm /tmp/tf.zip
	chmod u+x $@
