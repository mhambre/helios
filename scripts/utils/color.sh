#!/usr/bin/env bash

# shellcheck disable=SC2034
# Color variables in this file are intentionally consumed by scripts that source it.

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
