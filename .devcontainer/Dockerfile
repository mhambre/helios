FROM mcr.microsoft.com/devcontainers/rust:bullseye

# Install Core Development Dependencies (Required by Build Scripts)
RUN apt-get update \
  && apt-get -y install --no-install-recommends \
  build-essential \
  pkg-config \
  libssl-dev \
  ca-certificates \
  curl \
  git \
  gcc-multilib \
  libc6-dev-i386 \
  grub-efi-amd64 \
  grub-common \
  grub-pc-bin \
  xorriso \
  qemu-system-x86 \
  qemu-utils \
  efibootmgr \
  udev \
  mtools \
  && rm -rf /var/lib/apt/lists/*

USER vscode

ENV CARGO_HOME=/home/vscode/.cargo \
  RUSTUP_HOME=/home/vscode/.rustup \
  PATH=/home/vscode/.cargo/bin:${PATH}

# Add host target used by high-level crates
RUN rustup target add x86_64-unknown-linux-gnu || true

# Install nightly components used by low-level crate builds
RUN rustup toolchain install nightly || true \
  && rustup component add --toolchain nightly clippy rustfmt rust-src || true \
  && rustup target add --toolchain nightly x86_64-unknown-linux-gnu || true

WORKDIR /workspaces/helios
