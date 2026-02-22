#!/bin/bash

SCRIPT_FULL_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_FULL_PATH")"

BOOT_SECTOR_SIZE=512
ISO_SIZE_MB=64
ISO_SIZE_BYTES=$((ISO_SIZE_MB * 1024 * 1024))
ISO_SECTOR_COUNT=$((ISO_SIZE_BYTES / BOOT_SECTOR_SIZE))

. "${SCRIPT_DIR}/../utils/color.sh"
. "${SCRIPT_DIR}/../../.env"

echo "${BOLD}${BLUE}Building ISO...${RESET}"
mkdir -p ${ISO_BUILD_DIR}

# Check for required tools
if ! command -v grub-mkrescue &> /dev/null; then
    echo "${BOLD}${YELLOW}Warning:${RESET} ${YELLOW}grub-mkrescue is not installed. Please install it to build the ISO.${RESET}"
    exit 1
fi

if ! command -v xorriso &> /dev/null; then
    echo "${BOLD}${YELLOW}Warning:${RESET} ${YELLOW}xorriso is not installed. Please install it to build the ISO.${RESET}"
    exit 1
fi

if ! command -v fdisk &> /dev/null; then
    echo "${BOLD}${YELLOW}Warning:${RESET} ${YELLOW}fdisk is not installed. Please install it to build the ISO.${RESET}"
    exit 1
fi

dd if=/dev/zero of=${ISO_BUILD_DIR}/helios.iso bs=${BOOT_SECTOR_SIZE} count=${ISO_SECTOR_COUNT} || { echo "${BOLD}${RED}Error:${RESET} ${RED}Failed to create ISO image.${RESET}"; exit 1; }