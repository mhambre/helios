# helios-control make targets

# ===== Variables =====

CONTROL_COMPONENT = control
CONTROL_CRATE = helictl
CONTROL_BIN = $(CONTROL_CRATE)

# ===== Targets =====

# == Build Targets ==
# Build control in debug mode
.PHONY: ctl-debug cd
ctl-debug cd:
	$(call cargo_build_component,$(CONTROL_COMPONENT),$(CONTROL_CRATE),debug)
	@echo "$(CONTROL_CRATE) built successfully in debug mode: $(call target_dir_for_component,$(CONTROL_COMPONENT))/debug/$(CONTROL_BIN)"

# Build control in release mode
.PHONY: ctl-release cr
ctl-release cr:
	$(call cargo_build_component,$(CONTROL_COMPONENT),$(CONTROL_CRATE),release)
	@echo "$(CONTROL_CRATE) built successfully in release mode: $(call target_dir_for_component,$(CONTROL_COMPONENT))/release/$(CONTROL_BIN)"

# Run control in GDB (debug binary, host target only)
.PHONY: ctl-gdb cgdb
ctl-gdb cgdb: ctl-debug
	@if [ "$(call component_level,$(CONTROL_COMPONENT))" != "high" ]; then \
		echo "$(CONTROL_COMPONENT) is currently low-level; move it to high-level first (make set-high c=$(CONTROL_COMPONENT))."; \
		exit 1; \
	fi
	$(GDB) --args $(call target_dir_for_component,$(CONTROL_COMPONENT))/debug/$(CONTROL_BIN)
