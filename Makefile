CARGO = cargo
TARGET = x86_64-helios.json

.PHONY: kernel-debug
kernel-debug:
	$(CARGO) +nightly build --target $(TARGET)

.PHONY: kernel-release
kernel-release:
	$(CARGO) +nightly build --release --target $(TARGET)