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
  efibootmgr \
  udev \
  mtools \
  && rm -rf /var/lib/apt/lists/*
sudo apt-get update
sudo apt-get install -y


USER vscode

ENV CARGO_HOME=/home/vscode/.cargo \
  RUSTUP_HOME=/home/vscode/.rustup \
  PATH=/home/vscode/.cargo/bin:${PATH}

# Add the i686-unknown-none target for our OS development
RUN rustup target add i686-unknown-linux-gnu || true

# Install rustfmt and clippy for code formatting and linting
RUN rustup toolchain install nightly || true \
  && rustup component add clippy --toolchain nightly || true \
  && rustup component add --toolchain nightly-i686-unknown-linux-gnu rustfmt rust-src || true \
  && cargo fetch || true

WORKDIR /workspaces/helios
