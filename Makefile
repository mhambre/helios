# Helios Makefile

# === Variables ===

include .env

# General vars
CARGO = cargo

# Binary-Product Crates
KERNEL_CRATE = $(PROJECT)-core
DAEMON_CRATE = $(PROJECT)d
CLIENT_CRATE = $(PROJECT)ctl

# Kernel Build Target
TARGET = $(ARCH)-$(PROJECT)
TARGET_JSON = template/$(TARGET).json
TARGET_DIR = target/$(TARGET)
CORE_BIN = $(KERNEL_CRATE).elf

# Script Locations
BUILD_SCRIPTS = ./scripts/build


# === Targets ===

# == Build Targets ==
.PHONY: kernel-debug kd
kernel-debug kd:
	$(CARGO) +nightly build --target $(TARGET_JSON)

.PHONY: kernel-release kr
kernel-release kr:
	$(CARGO) +nightly build --release --target $(TARGET_JSON)

# == ISO Targets ==
.PHONY: debug-iso di
debug-iso di: kernel-debug
	cp $(TARGET_DIR)/debug/$(CORE_BIN) template/iso/boot/
	$(BUILD_SCRIPTS)/build-iso.sh

.PHONY: release-iso ri
release-iso ri: kernel-release
	cp $(TARGET_DIR)/release/$(CORE_BIN) template/iso/boot/
	$(BUILD_SCRIPTS)/build-iso.sh

