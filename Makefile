include .env

# Commands
CARGO = cargo

# Shared Locations
ROOT_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))
PROJECT_DIR := $(patsubst %/,%,$(dir $(ROOT_MAKEFILE)))
BUILD_SCRIPTS = $(PROJECT_DIR)/scripts/build

# Environment Variable Overrides
ARCH = $(shell uname -m)

include mk/core.mk

