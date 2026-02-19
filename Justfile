# Common Developer Tasks
set shell := ["bash", "-lc"]

# Check Rust Code Quality
check:
    cargo +nightly fmt -- --check
    cargo clippy --all-targets --all-features -- -D warnings
    cargo +nightly udeps --workspace --all-targets