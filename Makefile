.PHONY: help

help:
	@cat $(firstword $(MAKEFILE_LIST))
