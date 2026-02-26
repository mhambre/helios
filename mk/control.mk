# helios-control make targets

# ===== Variables =====

CRATE = $(PROJECT)ctl
BIN = $(CRATE)

# ===== Targets =====

# == Build Targets ==
# Build control in debug mode
.PHONY: ctl-debug kd
ctl-debug kd:
	$(CARGO) +nightly build -p $(CRATE) --target $(RUST_TARGET_JSON)
	@echo "$(CRATE) built successfully in debug mode: $(TARGET_DIR)/debug/$(BIN)"

# Build control in release mode
.PHONY: ctl-release kr
ctl-release cr:
	$(CARGO) +nightly build -p $(CRATE) --release --target $(RUST_TARGET_JSON)
	@echo "$(CRATE) built successfully in release mode: $(TARGET_DIR)/release/$(BIN)"
