# helid make targets

# ===== Variables =====

CRATE = $(PROJECT)d
BIN = $(CRATE)

# ===== Targets =====

# == Build Targets ==
# Build daemon in debug mode
.PHONY: d-debug kd
d-debug kd:
	$(CARGO) +nightly build -p $(CRATE) --target $(RUST_TARGET_JSON)
	@echo "$(CRATE) built successfully in debug mode: $(TARGET_DIR)/debug/$(BIN)"

# Build daemon in release mode
.PHONY: d-release kr
d-release kr:
	$(CARGO) +nightly build -p $(CRATE) --release --target $(RUST_TARGET_JSON)
	@echo "$(CRATE) built successfully in release mode: $(TARGET_DIR)/release/$(BIN)"
