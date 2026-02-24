#!/usr/bin/env bash
set -euo pipefail

SCRIPT_FULL_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_FULL_PATH")"

# shellcheck disable=SC1091
# shellcheck source=../utils/color.sh
. "${SCRIPT_DIR}/../utils/color.sh"

is_devcontainer() {
	if [[ "${REMOTE_CONTAINERS:-}" == "true" ]] || [[ -n "${CODESPACES:-}" ]]; then
		return 0
	fi

	if [[ -f /workspaces/.codespaces/shared/environment-setup.sh ]]; then
		return 0
	fi

	if [[ -d /workspaces ]] && [[ -n "$(ls -A /workspaces 2>/dev/null || true)" ]]; then
		return 0
	fi

	if [[ -f /.dockerenv ]]; then
		[[ -n "${VSCODE_IPC_HOOK_CLI:-}" || -n "${TERM_PROGRAM:-}" ]]
		return $?
	fi

	return 1
}

if is_devcontainer; then
	echo "${BOLD}${BLUE}Container check state: Running inside a devcontainer environment.${RESET}"
	exit 0
else
	echo "${BOLD}${BLUE}Container check state: Not running inside a devcontainer environment.${RESET}"
	exit 1
fi
