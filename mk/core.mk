# helios-core make targets

# ===== Variables =====

CORE_COMPONENT = core
CORE_CRATE = $(PROJECT)-core
CORE_BIN = $(CORE_CRATE).elf

# ===== Targets =====

# == Build Targets ==
# Build kernel in debug mode
.PHONY: kernel-debug kd
kernel-debug kd:
	$(call cargo_build_component,$(CORE_COMPONENT),$(CORE_CRATE),debug)
	grub-file --is-x86-multiboot2 $(call target_dir_for_component,$(CORE_COMPONENT))/debug/$(CORE_BIN) && echo "[build] Kernel binary is Multiboot2 compliant" || (echo "[err] Kernel binary is not Multiboot2 compliant" && exit 1)
	@echo "[build] Kernel built successfully in debug mode: $(call target_dir_for_component,$(CORE_COMPONENT))/debug/$(CORE_BIN)"

# Build kernel in release mode
.PHONY: kernel-release kr
kernel-release kr:
	$(call cargo_build_component,$(CORE_COMPONENT),$(CORE_CRATE),release)
	grub-file --is-x86-multiboot2 $(call target_dir_for_component,$(CORE_COMPONENT))/release/$(CORE_BIN) && echo "[build] Kernel binary is Multiboot2 compliant" || (echo "[err] Kernel binary is not Multiboot2 compliant" && exit 1)
	@echo "[build] Kernel built successfully in release mode: $(call target_dir_for_component,$(CORE_COMPONENT))/release/$(CORE_BIN)"

# == ISO Targets ==
# Build ISO with serial console for debugging
.PHONY: debug-iso-serial dis
debug-iso-serial dis: kernel-debug
	mkdir -p $(ISO_BUILD_DIR)-stage/boot/
	cp $(call target_dir_for_component,$(CORE_COMPONENT))/debug/$(CORE_BIN) $(ISO_BUILD_DIR)-stage/boot/
	$(BUILD_SCRIPTS)/build-iso.sh serial

# Build release ISO with serial console
.PHONY: release-iso-serial ris
release-iso-serial ris: kernel-release
	mkdir -p $(ISO_BUILD_DIR)-stage/boot/
	cp $(call target_dir_for_component,$(CORE_COMPONENT))/release/$(CORE_BIN) $(ISO_BUILD_DIR)-stage/boot/
	$(BUILD_SCRIPTS)/build-iso.sh serial

# == Run Targets ==
# Run QEMU with debug ISO (serial console)
.PHONY: qemu-debug-serial qds
qemu-debug-serial qds: debug-iso-serial
	@echo "[run] QEMU with debug ISO: $(ISO_BUILD_DIR)/$(PROJECT).iso"
	$(QEMU_EXECUTABLE) -cdrom $(ISO_BUILD_DIR)/$(PROJECT).iso -m $(QEMU_MEM) -nographic -serial mon:stdio

# Run QEMU with release ISO (serial console)
.PHONY: qemu-release-serial qrs
qemu-release-serial qrs: release-iso-serial
	@echo "[run] QEMU with release ISO: $(ISO_BUILD_DIR)/$(PROJECT).iso"
	$(QEMU_EXECUTABLE) -cdrom $(ISO_BUILD_DIR)/$(PROJECT).iso -m $(QEMU_MEM) -nographic -serial mon:stdio

# Run QEMU paused and expose GDB server for kernel debugging
.PHONY: kernel-qemu-gdb kqgdb
kernel-qemu-gdb kqgdb: debug-iso-serial
	@echo "[run] QEMU waiting for GDB on tcp::$(QEMU_GDB_PORT)"
	$(QEMU_EXECUTABLE) -cdrom $(ISO_BUILD_DIR)/$(PROJECT).iso -m $(QEMU_MEM) -nographic -serial mon:stdio -S -gdb tcp::$(QEMU_GDB_PORT)

# Attach rust-gdb to a waiting kernel QEMU GDB server
.PHONY: kernel-gdb kgdb
kernel-gdb kgdb: kernel-debug
	@echo "[run] Attaching rust-gdb to a waiting kernel QEMU GDB server"
	$(RUST_GDB) $(call target_dir_for_component,$(CORE_COMPONENT))/debug/$(CORE_BIN) \
		-ex "set confirm off" \
		-ex "target remote localhost:$(QEMU_GDB_PORT)"
