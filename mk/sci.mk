# helios-sci make targets

# ===== Variables =====

CRATE = $(PROJECT)-sci
BIN = $(CRATE)

# ===== Targets =====

# == Build Targets ==
# Build helios-sci in debug mode
.PHONY: sci-debug sd
sci-debug sd:
	$(CARGO) +nightly build -p $(CRATE) --target $(RUST_TARGET_JSON)
	@echo "$(CRATE) built successfully in debug mode: $(TARGET_DIR)/debug/$(BIN)"

# Build helios-sci in release mode
.PHONY: sci-release sr
sci-release sr:
	$(CARGO) +nightly build -p $(CRATE) --release --target $(RUST_TARGET_JSON)
	@echo "$(CRATE) built successfully in release mode: $(TARGET_DIR)/release/$(BIN)"
