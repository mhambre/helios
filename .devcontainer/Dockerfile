FROM mcr.microsoft.com/devcontainers/rust:bullseye

# Install Core Development Dependencies 
RUN apt-get update \
  && apt-get -y install --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    ca-certificates \
    curl \
    git \
    ripgrep \
    gdb \
    fzf
  && rm -rf /var/lib/apt/lists/*

USER vscode

ENV CARGO_HOME=/home/vscode/.cargo \
    RUSTUP_HOME=/home/vscode/.rustup \
    PATH=/home/vscode/.cargo/bin:${PATH}
    
# Add the x86_64-unknown-none target for our OS development
RUN rustup target add x86_64-unknown-none || true

# Install rustfmt and clippy for code formatting and linting
RUN rustup toolchain install nightly || true \
&& rustup component add rust-src clippy --toolchain nightly || true \
&& rustup component add --toolchain nightly-x86_64-unknown-linux-gnu rustfmt || true \
    && cargo fetch || true

# Install cargo devex tools
RUN cargo install --locked \
    cargo-udeps \
    cargo-nextest \
    just \
    just-lsp

WORKDIR /workspaces/helios
