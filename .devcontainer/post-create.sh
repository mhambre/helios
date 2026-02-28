#!/usr/bin/env bash
set -euo pipefail

SCRIPT_FULL_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_FULL_PATH")"

# shellcheck disable=SC1091
# shellcheck source=../scripts/utils/color.sh
source "${SCRIPT_DIR}/../scripts/utils/color.sh"

echo "${BOLD}${BLUE}Running post-create tasks...${RESET}"

echo "${BOLD}${GREEN}Ensuring Rust nightly components are installed...${RESET}"
rustup toolchain install nightly-x86_64-unknown-linux-gnu
rustup target add x86_64-unknown-none --toolchain nightly-x86_64-unknown-linux-gnu
rustup component add rust-src rustfmt clippy --toolchain nightly-x86_64-unknown-linux-gnu

# Install non-critical devex packages
echo "${BOLD}${GREEN}Installing additional tools via apt...${RESET}"
sudo apt update && sudo apt install -y \
	bat \
	shellcheck \
	fzf \
	ripgrep \
	gdb \
	rust-gdb && \
	sudo rm -rf /var/lib/apt/lists/*

# Install non-critical cargo devex tools
echo "${BOLD}${GREEN}Installing additional tools via cargo...${RESET}"
cargo install --locked \
	cargo-udeps \
	cargo-nextest \
	just-lsp

echo "${BOLD}${GREEN}Installing tools with custom installers...${RESET}"

# Install shell formatter
curl -sS https://webi.sh/shfmt | sh
# shellcheck source=/dev/null
source ~/.config/envman/PATH.env

# My name is gef
bash -c "$(curl -fsSL https://gef.blah.cat/sh)"

echo "${BOLD}${BLUE}Post-create tasks complete.${RESET}"
