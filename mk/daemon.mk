# helid make targets

# ===== Variables =====

DAEMON_COMPONENT = daemon
DAEMON_CRATE = helid
DAEMON_BIN = $(DAEMON_CRATE)

# ===== Targets =====

# == Build Targets ==
# Build daemon in debug mode
.PHONY: daemon-debug d-debug dd
daemon-debug d-debug dd:
	$(call cargo_build_component,$(DAEMON_COMPONENT),$(DAEMON_CRATE),debug)
	@echo "$(DAEMON_CRATE) built successfully in debug mode: $(call target_dir_for_component,$(DAEMON_COMPONENT))/debug/$(DAEMON_BIN)"

# Build daemon in release mode
.PHONY: daemon-release d-release dr
daemon-release d-release dr:
	$(call cargo_build_component,$(DAEMON_COMPONENT),$(DAEMON_CRATE),release)
	@echo "$(DAEMON_CRATE) built successfully in release mode: $(call target_dir_for_component,$(DAEMON_COMPONENT))/release/$(DAEMON_BIN)"

# Run daemon in GDB (debug binary, host target only)
.PHONY: daemon-gdb dgdb
daemon-gdb dgdb: daemon-debug
	@if [ "$(call component_level,$(DAEMON_COMPONENT))" != "high" ]; then \
		echo "$(DAEMON_COMPONENT) is currently low-level; move it to high-level first (make set-high c=$(DAEMON_COMPONENT))."; \
		exit 1; \
	fi
	$(GDB) --args $(call target_dir_for_component,$(DAEMON_COMPONENT))/debug/$(DAEMON_BIN)
