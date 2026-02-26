include .env

# Commands
CARGO = cargo

# Shared Locations
ROOT_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))
PROJECT_DIR := $(patsubst %/,%,$(dir $(ROOT_MAKEFILE)))
BUILD_SCRIPTS = $(PROJECT_DIR)/scripts/build
TARGET_DIR = target/$(RUST_TARGET)

# Environment Variable Overrides
ARCH = $(shell uname -m)

include mk/core.mk
include mk/control.mk
include mk/daemon.mk
include mk/sci.mk

# === Aggregate Targets ===
.PHONY: all-release ar
all-release ar: kr cr dr sr

.PHONY: high-level hl
high-level hl:
	RUST_TARGET=x86_64-unknown-linux-gnu
	make cr dr sr

.PHONY: os
os:
	@echo "Composite OS build target. Use 'make kr' for kernel, 'make cr' for control, 'make dr' for daemon, and 'make sr' for sci."
	@echo "Not implemented: 'make os' is a placeholder for building all components together. Use individual targets for now."
	exit 1

# === Clean Targets ===
.PHONY: clean
clean:
	$(CARGO) clean
	rm -rf build/*
