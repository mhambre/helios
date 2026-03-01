# Contributing to Helios

Thanks for contributing.

This document covers the default contribution workflow for the Helios monorepo and its crate submodules.

## Ground Rules

- Keep changes focused and small.
- Prefer clear, incremental PRs over large rewrites.
- Keep build/test/lint passing before opening a PR.
- Update docs when behavior or workflows change.
- Follow the [coding standards](./docs/development/standards.md).

## Local Setup

Clone with submodules:

```bash
git clone --recurse-submodules git@github.com:mhambre/helios.git
cd helios
```

If you already cloned:

```bash
git submodule update --init --recursive
```

## Branch + Commit Workflow

1. Add an issue to the corresponding submodule repository.
2. Create a branch from `main`.
3. Make your change.
4. Run checks locally.
5. Commit with a clear message.
6. Open a pull request.
7. Name pull request using the [conventional commits standards](https://www.conventionalcommits.org/en/v1.0.0-beta.2/). Adding scope is optional but preferred.
8. Link the associated issue.
9. [Bump the submodule pointer](#working-with-submodules) in the `helios` root repository.

Example:

```bash
git checkout -b feat/short-description
```

## Checks Before PR

Run the standard checks from repo root:

```bash
just check
just build-check
```

If your change is limited in scope, run at least the relevant subset (for example `just rust-clippy` or `just shell-fmt-check`).

## Code Style

- Rust: `cargo fmt` formatting, clippy clean (`-D warnings` expected in CI paths).
- Shell: `shfmt` + `shellcheck`.
- Keep comments concise and only where useful.
- Adhere to [coding standards](./docs/development/standards.md).

## Working With Submodules

Crates in `crates/` are separate repos.

If you change a submodule:

1. Commit inside the submodule repo first.
2. Push that submodule commit.
3. Return to the Helios root and commit the updated submodule pointer.

Example:

```bash
# inside submodule
cd crates/helictl
git add .
git commit -m "..."
git push

# back in helios root
cd ../..
git add crates/helictl
git commit -m "chore(helios-http-8): Bump helictl submodule"
```

## Pull Request Notes

PR descriptions should include:

- What changed
- Why it changed
- How it was tested
- Any follow-up work

## Questions

If something is unclear, open an issue or draft PR with context and proposed direction.
