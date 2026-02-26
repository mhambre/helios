# helios-core make targets

# ===== Variables =====

CRATE = $(PROJECT)-core
TARGET_DIR = target/$(RUST_TARGET)
BIN = $(CRATE).elf

# ===== Targets =====

# == Build Targets ==
# Build kernel in debug mode
.PHONY: kernel-debug kd
kernel-debug kd:
	$(CARGO) +nightly build -p $(CRATE) --target $(RUST_TARGET_JSON)
	grub-file --is-x86-multiboot2 $(TARGET_DIR)/debug/$(BIN) && echo "Kernel binary is Multiboot2 compliant" || (echo "Kernel binary is not Multiboot2 compliant" && exit 1)
	@echo "Kernel built successfully in debug mode: $(TARGET_DIR)/debug/$(BIN)"

# Build kernel in release mode
.PHONY: kernel-release kr
kernel-release kr:
	$(CARGO) +nightly build -p $(CRATE) --release --target $(RUST_TARGET_JSON)
	grub-file --is-x86-multiboot2 $(TARGET_DIR)/release/$(BIN) && echo "Kernel binary is Multiboot2 compliant" || (echo "Kernel binary is not Multiboot2 compliant" && exit 1)
	@echo "Kernel built successfully in release mode: $(TARGET_DIR)/release/$(BIN)"

# == ISO Targets ==
# Build ISO with serial console for debugging
.PHONY: debug-iso-serial dis
debug-iso-serial dis: kernel-debug
	mkdir -p $(ISO_BUILD_DIR)-stage/boot/
	cp $(TARGET_DIR)/debug/$(BIN) $(ISO_BUILD_DIR)-stage/boot/
	$(BUILD_SCRIPTS)/build-iso.sh serial

# Build release ISO with serial console
.PHONY: release-iso-serial ris
release-iso-serial ris: kernel-release
	mkdir -p $(ISO_BUILD_DIR)-stage/boot/
	cp $(TARGET_DIR)/release/$(BIN) $(ISO_BUILD_DIR)-stage/boot/
	$(BUILD_SCRIPTS)/build-iso.sh serial

# == Run Targets ==
# Run QEMU with debug ISO (serial console)
.PHONY: qemu-debug-serial qds
qemu-debug-serial qds: debug-iso-serial
	@echo $(ISO_BUILD_DIR)/$(PROJECT).iso
	$(QEMU_EXECUTABLE) -cdrom $(ISO_BUILD_DIR)/$(PROJECT).iso -m $(QEMU_MEM) -nographic -serial mon:stdio

# Run QEMU with release ISO (serial console)
.PHONY: qemu-release-serial qrs
qemu-release-serial qrs: release-iso-serial
	$(QEMU_EXECUTABLE) -cdrom $(ISO_BUILD_DIR)/$(PROJECT).iso -m $(QEMU_MEM) -nographic -serial mon:stdio
