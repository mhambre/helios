#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JUSTFILE_PATH="${JUSTFILE_PATH:-${PROJECT_DIR}/Justfile}"

if [[ ! -f "${JUSTFILE_PATH}" ]]; then
	echo "error: Justfile not found at ${JUSTFILE_PATH}" >&2
	exit 1
fi

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
	RESET="$(tput sgr0)"
	BOLD="$(tput bold)"
	DIM="$(tput dim)"
	BLUE="$(tput setaf 4)"
	CYAN="$(tput setaf 6)"
	GREEN="$(tput setaf 2)"
	YELLOW="$(tput setaf 3)"
else
	RESET=""
	BOLD=""
	DIM=""
	BLUE=""
	CYAN=""
	GREEN=""
	YELLOW=""
fi

print_header() {
	echo "${BOLD}${BLUE}───────────────────────${RESET}"
	echo "${BOLD}${CYAN}     Helios Tasks${RESET}"
	echo "${BOLD}${BLUE}───────────────────────${RESET}"
	echo "${DIM}Usage:${RESET} ${GREEN}just <task>${RESET}"
	echo
}

print_tasks() {
	awk '
		function trim(s) {
			gsub(/^[ \t]+|[ \t]+$/, "", s)
			return s
		}

		BEGIN {
			section = "General"
			pending_doc = ""
			count = 0
		}

		/^\s*#\s*@section\s+/ {
			line = $0
			sub(/^\s*#\s*@section\s+/, "", line)
			section = trim(line)
			next
		}

		/^\s*#\s*/ {
			line = $0
			sub(/^\s*#\s?/, "", line)
			line = trim(line)

			if (line == "" || line ~ /^@section\s+/) {
				next
			}

			if (pending_doc == "") {
				pending_doc = line
			}
			next
		}

		/^\s*[A-Za-z_][A-Za-z0-9_-]*\s*:/ {
			line = $0
			sub(/^\s*/, "", line)
			split(line, parts, ":")
			name = trim(parts[1])

			if (name == "default" || name ~ /^_/) {
				pending_doc = ""
				next
			}

			desc = (pending_doc == "" ? "(no description)" : pending_doc)
			key = section SUBSEP name
			items[key] = desc
			sections[section] = 1
			count++
			pending_doc = ""
			next
		}

		{
			pending_doc = ""
		}

		END {
			if (count == 0) {
				print "NO_TASKS"
				exit
			}

			for (s in sections) {
				print "SECTION" SUBSEP s
			}

			for (k in items) {
				split(k, p, SUBSEP)
				print "ITEM" SUBSEP p[1] SUBSEP p[2] SUBSEP items[k]
			}
		}
	' "${JUSTFILE_PATH}" | sort -t $'\034' -k2,2 -k3,3
}

render_menu() {
	local output
	output="$(print_tasks)"

	if grep -q '^NO_TASKS$' <<< "${output}"; then
		echo "${YELLOW}No public tasks found in ${JUSTFILE_PATH}.${RESET}"
		return
	fi

	local current_section=""
	while IFS=$'\034' read -r kind a b c; do
		[[ "${kind}" == "ITEM" ]] || continue

		if [[ "${a}" != "${current_section}" ]]; then
			current_section="${a}"
			echo "${BOLD}${GREEN}${current_section}${RESET}"
		fi

		printf "  ${CYAN}%-18s${RESET} %s\n" "${b}" "${c}"
	done <<< "${output}"
}

print_header
render_menu
