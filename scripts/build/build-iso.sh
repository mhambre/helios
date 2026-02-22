#!/bin/bash

SCRIPT_FULL_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_FULL_PATH")"

BOOT_SECTOR_SIZE=512 # Standard boot sector size
ISO_SIZE_MB=64       # Need enough space for the kernel, initramfs, and GRUB files. Adjust as needed.
ISO_SIZE_BYTES=$((ISO_SIZE_MB * 1024 * 1024))
ISO_SECTOR_COUNT=$((ISO_SIZE_BYTES / BOOT_SECTOR_SIZE))

# shellcheck disable=SC1091
# shellcheck source=../utils/color.sh
. "${SCRIPT_DIR}/../utils/color.sh"
# shellcheck disable=SC2016
# shellcheck source=../../.env
. "${SCRIPT_DIR}/../../.env"

ISO_BUILD_DIR="${BUILD_DIR}/iso"
ISO_STAGE_DIR="${BUILD_DIR}/iso-stage"
GRUB_CFG_TEMPLATE_DIR="${PROJECT_DIR}/template/grub-cfg"
GRUB_CFG_OUTPUT_DIR="${ISO_STAGE_DIR}/boot/grub"
ISO_NAME="${PROJECT}.iso"

# Script Args
GRUB_DISPLAY_TYPE=${1:-"graphic"}

echo "${BOLD}${BLUE}Building ISO...${RESET}"
mkdir -p "${ISO_BUILD_DIR}"
mkdir -p "${GRUB_CFG_OUTPUT_DIR}"

# Select the appropriate GRUB configuration
if [ "$GRUB_DISPLAY_TYPE" == "serial" ]; then
	echo "${BOLD}${YELLOW}Note:${RESET} ${YELLOW}Serial console enabled in GRUB configuration.${RESET}"
	cp "${GRUB_CFG_TEMPLATE_DIR}/serial.cfg" "${GRUB_CFG_OUTPUT_DIR}/grub.cfg"
elif [ "$GRUB_DISPLAY_TYPE" == "graphic" ]; then
	echo "${BOLD}${YELLOW}Note:${RESET} ${YELLOW}Graphical console enabled in GRUB configuration.${RESET}"
	cp "${GRUB_CFG_TEMPLATE_DIR}/graphic.cfg" "${GRUB_CFG_OUTPUT_DIR}/grub.cfg"
else
	echo "${BOLD}${RED}Error:${RESET} ${RED}Invalid display type specified. Use 'serial' or 'graphic'.${RESET}"
	exit 1
fi

# Dependency checks
if ! command -v parted &>/dev/null; then
	echo "${BOLD}${YELLOW}Warning:${RESET} ${YELLOW}parted is not installed. Please install it to build the ISO.${RESET}"
	exit 1
fi

if ! command -v grub-mkrescue &>/dev/null; then
	echo "${BOLD}${YELLOW}Warning:${RESET} ${YELLOW}grub-mkrescue is not installed. Install grub-common grub-pc-bin xorriso.${RESET}"
	exit 1
fi

if ! command -v xorriso &>/dev/null; then
	echo "${BOLD}${YELLOW}Warning:${RESET} ${YELLOW}xorriso is not installed. Please install it to build the ISO.${RESET}"
	exit 1
fi

# Create an empty ISO image that is bootable
dd if=/dev/zero of="${ISO_BUILD_DIR}/${ISO_NAME}.tmp" bs=${BOOT_SECTOR_SIZE} count=${ISO_SECTOR_COUNT} || {
	echo "${BOLD}${RED}Error:${RESET} ${RED}Failed to create ISO image.${RESET}"
	exit 1
}

# Create a partition table and a single partition on the ISO image
parted -s "${ISO_BUILD_DIR}/${ISO_NAME}.tmp" \
	mklabel msdos \
	mkpart primary ext4 1MiB 100% \
	set 1 boot on

# Copy the kernel, and GRUB files to the mounted partition
echo "${BOLD}${GREEN}Building GRUB ISO with grub-mkrescue...${RESET}"
grub-mkrescue -o "${ISO_BUILD_DIR}/${ISO_NAME}" "${ISO_STAGE_DIR}" >/dev/null || {
	echo "${BOLD}${RED}Error:${RESET} ${RED}Failed to create ISO with grub-mkrescue.${RESET}"
	exit 1
}
rm -f "${ISO_BUILD_DIR}/${ISO_NAME}.tmp"

echo "${BOLD}${GREEN}ISO created:${RESET} ${ISO_BUILD_DIR}/${ISO_NAME}"
