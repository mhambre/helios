# helios-sci make targets

# ===== Variables =====

SCI_COMPONENT = sci
SCI_CRATE = $(PROJECT)-sci
SCI_BIN = $(SCI_CRATE)

# ===== Targets =====

# == Build Targets ==
# Build helios-sci in debug mode
.PHONY: sci-debug sd
sci-debug sd:
	$(call cargo_build_component,$(SCI_COMPONENT),$(SCI_CRATE),debug)
	@echo "[build] $(SCI_CRATE) built successfully in debug mode: $(call target_dir_for_component,$(SCI_COMPONENT))/debug/$(SCI_BIN)"

# Build helios-sci in release mode
.PHONY: sci-release sr
sci-release sr:
	$(call cargo_build_component,$(SCI_COMPONENT),$(SCI_CRATE),release)
	@echo "[build] $(SCI_CRATE) built successfully in release mode: $(call target_dir_for_component,$(SCI_COMPONENT))/release/$(SCI_BIN)"

# Run sci in GDB (debug binary, host target only)
.PHONY: sci-gdb sgdb
sci-gdb sgdb: sci-debug
	@if [ "$(call component_level,$(SCI_COMPONENT))" != "high" ]; then \
		echo "[err] $(SCI_COMPONENT) is currently low-level; move it to high-level first (make set-high c=$(SCI_COMPONENT))."; \
		exit 1; \
	fi
	$(GDB) --args $(call target_dir_for_component,$(SCI_COMPONENT))/debug/$(SCI_BIN)
