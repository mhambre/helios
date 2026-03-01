# Common Developer Tasks
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

PROJECT_DIR := justfile_directory()

_default:
  {{PROJECT_DIR}}/scripts/dev/just-menu.sh

_start name:
  @printf "\033[0;33m==> %s...\033[0m\n" "{{name}}"

_stage name stage:
  @printf "\033[0;36m   • %s:\033[0m %s\n" "{{name}}" "{{stage}}"

_pass name:
  @printf "\033[0;32m☑ PASS\033[0m %s\n" "{{name}}"

_fail name:
  @printf "\033[0;31m☒ FAIL\033[0m %s\n" "{{name}}"

_run name:
  @just _start "{{name}}"
  @if just "{{name}}"; then \
      just _pass "{{name}}"; \
    else \
      rc=$?; \
      just _fail "{{name}}"; \
      exit "$rc"; \
    fi

# @section General Code Quality

# Run all code-quality related checks for all languages
check:
  @just _run rust-check
  @just _run shell-check
  @just _run rust-fmt-check
  @just _run shell-fmt-check

# Format all code for all languages
fmt:
  @just _run rust-fmt
  @just _run shell-fmt

# Check formatting for all languages
fmt-check:
  @just _run rust-fmt-check
  @just _run shell-fmt-check

# @section Fine-grained Code Quality

# Runs clippy and udeps to check for lints and unused dependencies
rust-check:
  @just _run rust-clippy
  @just _run rust-udeps

# Runs clippy and fails on warnings
rust-clippy:
  @just _stage rust-clippy "cargo +nightly clippy"
  @bash -eu -o pipefail -c '\
    set -a; source ./.env; set +a; \
    arch="${ARCH:-$(uname -m)}"; \
    low_target="${LOW_LEVEL_TARGET:-${PROJECT_DIR}/template/${arch}-${PROJECT}.json}"; \
    high_target="${HIGH_LEVEL_TARGET:-${arch}-unknown-linux-gnu}"; \
    map_pkg() { \
      case "$1" in \
        core) echo "helios-core" ;; \
        control) echo "helictl" ;; \
        daemon) echo "helid" ;; \
        sci) echo "helios-sci" ;; \
        *) return 1 ;; \
      esac; \
    }; \
    for c in ${LOW_LEVEL_CRATES:-core}; do \
      p="$(map_pkg "$c")" || continue; \
      echo "[clippy] low  crate=$c pkg=$p target=$low_target"; \
      cargo +nightly --config .cargo/config.toml clippy -Zjson-target-spec -p "$p" --target "$low_target" ${LOW_LEVEL_CARGO_FLAGS:-} --all-features -- -D warnings; \
    done; \
    for c in ${HIGH_LEVEL_CRATES:-control daemon sci http}; do \
      p="$(map_pkg "$c")" || continue; \
      echo "[clippy] high crate=$c pkg=$p target=$high_target"; \
      cargo +nightly --config .cargo/config.toml clippy -p "$p" --target "$high_target" ${HIGH_LEVEL_CARGO_FLAGS:-} --all-features -- -D warnings; \
    done \
  '

# Runs cargo-udeps with nightly
rust-udeps:
  @just _stage rust-udeps "cargo +nightly udeps"
  @bash -eu -o pipefail -c '\
    set -a; source ./.env; set +a; \
    arch="${ARCH:-$(uname -m)}"; \
    low_target="${LOW_LEVEL_TARGET:-${PROJECT_DIR}/template/${arch}-${PROJECT}.json}"; \
    high_target="${HIGH_LEVEL_TARGET:-${arch}-unknown-linux-gnu}"; \
    map_pkg() { \
      case "$1" in \
        core) echo "helios-core" ;; \
        control) echo "helictl" ;; \
        daemon) echo "helid" ;; \
        sci) echo "helios-sci" ;; \
        http) echo "helios-http" ;; \
        *) return 1 ;; \
      esac; \
    }; \
    for c in ${LOW_LEVEL_CRATES:-core}; do \
      p="$(map_pkg "$c")" || continue; \
      echo "[udeps] skip low crate=$c pkg=$p (custom target not reliably supported by cargo-udeps)"; \
    done; \
    for c in ${HIGH_LEVEL_CRATES:-control daemon sci http}; do \
      p="$(map_pkg "$c")" || continue; \
      echo "[udeps] high crate=$c pkg=$p target=$high_target"; \
      RUSTFLAGS="-Zunstable-options" cargo +nightly --config .cargo/config.toml udeps -p "$p" --target "$high_target" ${HIGH_LEVEL_CARGO_FLAGS:-}; \
    done \
  '

# Formats all Rust files
rust-fmt:
  @just _stage rust-fmt "cargo fmt"
  cargo +nightly --config .cargo/config.toml fmt

# Runs cargo fmt in check mode, which returns non-zero if any files are not formatted
rust-fmt-check:
  @just _stage rust-fmt-check "cargo fmt --check"
  cargo +nightly --config .cargo/config.toml fmt -- --check

# Runs shellcheck on all *.sh files everywhere except pruned dirs
shell-check:
  @just _stage shell-check "shellcheck"
  find . \
    \( -path './.git' -o -path './target' -o -path './build' \) -prune -o \
    -type f -name '*.sh' -print0 \
    | xargs -0 -r shellcheck

# Formats all shell files
shell-fmt:
  @just _stage shell-fmt "shfmt -w"
  find . \
    \( -path './.git' -o -path './target' -o -path './build' \) -prune -o \
    -type f -name '*.sh' -print0 \
    | xargs -0 -r shfmt -w

# Checks formatting for *.sh everywhere except pruned dirs
shell-fmt-check:
  @just _stage shell-fmt-check "shfmt -d"
  find . \
    \( -path './.git' -o -path './target' -o -path './build' \) -prune -o \
    -type f -name '*.sh' -print0 \
    | xargs -0 -r shfmt -d >/dev/null

# @section Build Levels

# Show current low/high crate mapping and resolved targets/flags
level-status:
  @just _stage level-status "make level-status"
  make level-status

# Build a component using current level mapping
build crate profile="release":
  @just _stage build "crate={{crate}} profile={{profile}}"
  @case "{{crate}}:{{profile}}" in \
    core:debug) make kd ;; \
    core:release) make kr ;; \
    control:debug) make cd ;; \
    control:release) make cr ;; \
    daemon:debug) make dd ;; \
    daemon:release) make dr ;; \
    sci:debug) make sd ;; \
    sci:release) make sr ;; \
    http:debug) make hd ;; \
    http:release) make hr ;; \
    *) echo "Usage: just build <core|control|daemon|sci|http> [debug|release]"; exit 1 ;; \
  esac

# Run a component under GDB
gdb crate:
  @just _stage gdb "crate={{crate}}"
  @case "{{crate}}" in \
    core) make kgdb ;; \
    control) make cgdb ;; \
    daemon) make dgdb ;; \
    sci) make sgdb ;; \
    http) make hgdb ;; \
    *) echo "Usage: just gdb <core|control|daemon|sci|http>"; exit 1 ;; \
  esac

# Start kernel QEMU in paused mode with GDB stub enabled
kernel-qemu-gdb:
  @just _stage kernel-qemu-gdb "make kqgdb"
  make kqgdb
