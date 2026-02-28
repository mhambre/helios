include .env

# Commands
CARGO ?= cargo
GDB ?= $(GDB_EXECUTABLE)
RUST_GDB ?= $(RUST_GDB_EXECUTABLE)

# Shared Locations
ROOT_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))
PROJECT_DIR := $(patsubst %/,%,$(dir $(ROOT_MAKEFILE)))
BUILD_SCRIPTS = $(PROJECT_DIR)/scripts/build

# Environment Variable Overrides
ARCH := $(shell uname -m)

# Compilation level defaults (can be overridden in .env or CLI)
LOW_LEVEL_TARGET ?= $(PROJECT_DIR)/template/$(ARCH)-$(PROJECT).json
HIGH_LEVEL_TARGET ?= $(ARCH)-unknown-linux-gnu
LOW_LEVEL_CARGO_FLAGS ?=
HIGH_LEVEL_CARGO_FLAGS ?=
QEMU_GDB_PORT ?= 1234

# If .env provided shell-style expressions (containing '$'), use make-safe defaults.
ifneq ($(findstring $$,$(LOW_LEVEL_TARGET)),)
LOW_LEVEL_TARGET := $(PROJECT_DIR)/template/$(ARCH)-$(PROJECT).json
endif
ifneq ($(findstring $$,$(HIGH_LEVEL_TARGET)),)
HIGH_LEVEL_TARGET := $(ARCH)-unknown-linux-gnu
endif

# Normalize env lists for reliable make filtering.
empty :=
space := $(empty) $(empty)
comma := ,
normalize_list = $(strip $(subst $(comma),$(space),$(subst ",,$(1))))
LOW_LEVEL_CRATES_SET := $(call normalize_list,$(LOW_LEVEL_CRATES))
HIGH_LEVEL_CRATES_SET := $(call normalize_list,$(HIGH_LEVEL_CRATES))

component_level = $(if $(filter $(1),$(HIGH_LEVEL_CRATES_SET)),high,low)
target_for_component = $(if $(filter $(1),$(HIGH_LEVEL_CRATES_SET)),$(HIGH_LEVEL_TARGET),$(LOW_LEVEL_TARGET))
sanitize_flags = $(strip $(subst ",,$(1)))
cargo_flags_for_component = $(call sanitize_flags,$(if $(filter $(1),$(HIGH_LEVEL_CRATES_SET)),$(HIGH_LEVEL_CARGO_FLAGS),$(LOW_LEVEL_CARGO_FLAGS)))
target_dir_name = $(patsubst %.json,%,$(notdir $(strip $(1))))
target_dir_for_component = target/$(call target_dir_name,$(call target_for_component,$(1)))
unstable_flags_for_target = $(if $(filter %.json,$(strip $(1))),-Zjson-target-spec,)

define cargo_build_component
	@echo "[build] component=$(1) level=$(call component_level,$(1)) crate=$(2) target=$(call target_for_component,$(1)) flags=$(call cargo_flags_for_component,$(1))"
	$(CARGO) +nightly build $(call unstable_flags_for_target,$(call target_for_component,$(1))) -p $(2) $(if $(filter release,$(3)),--release,) --target $(call target_for_component,$(1)) $(CARGO_FLAGS) $(call cargo_flags_for_component,$(1))
endef

include mk/core.mk
include mk/control.mk
include mk/daemon.mk
include mk/sci.mk

# === Aggregate Targets ===
# Build all components in release mode
.PHONY: all-release ar
all-release ar: kr cr dr sr

# Build all components in debug mode
.PHONY: all-debug ad
all-debug ad: kd cd dd sd

# High-level release build-all
.PHONY: high-level-release hlr
high-level-release hlr:
	$(MAKE) cr dr sr

# High-level debug build-all
.PHONY: high-level-debug hld
high-level-debug hld:
	$(MAKE) cd dd sd

# Print current levels and targets for each component
.PHONY: level-status ls
level-status ls:
	@echo "LOW_LEVEL_CRATES=$(LOW_LEVEL_CRATES_SET)"
	@echo "HIGH_LEVEL_CRATES=$(HIGH_LEVEL_CRATES_SET)"
	@echo "LOW_LEVEL_TARGET=$(LOW_LEVEL_TARGET)"
	@echo "HIGH_LEVEL_TARGET=$(HIGH_LEVEL_TARGET)"
	@echo
	@printf "%-8s %-5s %-30s %s\n" "crate" "level" "target" "flags"
	@printf "%-8s %-5s %-30s %s\n" "core" "$(call component_level,core)" "$(call target_for_component,core)" "$(call cargo_flags_for_component,core)"
	@printf "%-8s %-5s %-30s %s\n" "control" "$(call component_level,control)" "$(call target_for_component,control)" "$(call cargo_flags_for_component,control)"
	@printf "%-8s %-5s %-30s %s\n" "daemon" "$(call component_level,daemon)" "$(call target_for_component,daemon)" "$(call cargo_flags_for_component,daemon)"
	@printf "%-8s %-5s %-30s %s\n" "sci" "$(call component_level,sci)" "$(call target_for_component,sci)" "$(call cargo_flags_for_component,sci)"

# Build the entire OS (all components) in release mode
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
