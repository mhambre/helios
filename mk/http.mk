# helios-control make targets

# ===== Variables =====

HTTP_COMPONENT = http
HTTP_CRATE = $(PROJECT)-http
HTTP_BIN = $(HTTP_CRATE)

# ===== Targets =====

# == Build Targets ==
# Build control in debug mode
.PHONY: http-debug hd
http-debug hd:
	$(call cargo_build_component,$(HTTP_COMPONENT),$(HTTP_CRATE),debug)
	@echo "$(HTTP_CRATE) built successfully in debug mode: $(call target_dir_for_component,$(HTTP_COMPONENT))/debug/$(HTTP_BIN)"

# Build control in release mode
.PHONY: http-release hr
http-release hr:
	$(call cargo_build_component,$(HTTP_COMPONENT),$(HTTP_CRATE),release)
	@echo "$(HTTP_CRATE) built successfully in release mode: $(call target_dir_for_component,$(HTTP_COMPONENT))/release/$(HTTP_BIN)"

# Run control in GDB (debug binary, host target only)
.PHONY: http-gdb hgdb
http-gdb hgdb: http-debug
	@if [ "$(call component_level,$(HTTP_COMPONENT))" != "high" ]; then \
		echo "$(HTTP_COMPONENT) is currently low-level; move it to high-level first (make set-high c=$(HTTP_COMPONENT))."; \
		exit 1; \
	fi
	$(GDB) --args $(call target_dir_for_component,$(HTTP_COMPONENT))/debug/$(HTTP_BIN)
