# Common Developer Tasks
set shell := ["bash", "-lc"]

PROJECT_DIR := justfile_directory()

default:
    {{PROJECT_DIR}}/scripts/dev/just-menu.sh

# @section DevEx Tasks

# Code Quality Checks
check:
    cargo +nightly fmt -- --check
    cargo clippy --all-targets --all-features -- -D warnings
    cargo +nightly udeps --workspace --all-targets
