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
GRUB_CFG_TEMPLATE_DIR="${PROJECT_DIR}/template/grub-cfg"
GRUB_CFG_OUTPUT_DIR="${BUILD_DIR}/iso-stage/iso/boot/grub"

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

# Check for required tools
if ! command -v grub-install &>/dev/null; then
	echo "${BOLD}${YELLOW}Warning:${RESET} ${YELLOW}grub-install is not installed. Please install it to build the ISO.${RESET}"
	exit 1
fi

if ! command -v parted &>/dev/null; then
	echo "${BOLD}${YELLOW}Warning:${RESET} ${YELLOW}parted is not installed. Please install it to build the ISO.${RESET}"
	exit 1
fi

# Create an empty ISO image that is bootable
dd if=/dev/zero of="${ISO_BUILD_DIR}/helios.iso" bs=${BOOT_SECTOR_SIZE} count=${ISO_SECTOR_COUNT} || {
	echo "${BOLD}${RED}Error:${RESET} ${RED}Failed to create ISO image.${RESET}"
	exit 1
}

# Create a partition table and a single partition on the ISO image
parted -s "${ISO_BUILD_DIR}/helios.iso" \
	mklabel msdos \
	mkpart primary ext4 1MiB 100% \
	set 1 boot on

# Loop device setup (1: GRUB needed for bootloader, 2: Needed to write the kernel to the ISO image in the first partition)
LOOPDEV=$(sudo losetup --find --partscan --show "${ISO_BUILD_DIR}/helios.iso")
sudo mkfs.ext4 "${LOOPDEV}p1"

# Mount the partition so we can copy files to it
MNT=$(mktemp -d)
sudo mount "${LOOPDEV}p1" "$MNT" || {
	echo "${BOLD}${RED}Error:${RESET} ${RED}Failed to mount the partition.${RESET}"
	exit 1
}

# Add the kernel to the ISO image (in the first partition) and let GRUB install the bootloader to the disk loop device
echo "${BOLD}${GREEN}Installing GRUB + Kernel to ISO image...${RESET}"
sudo grub-install --target="${GRUB_TARGET}" --root-directory="$MNT" --no-floppy --modules="normal part_msdos ext4 multiboot biosdev" "${LOOPDEV}" || {
	echo "${BOLD}${RED}Error:${RESET} ${RED}Failed to install GRUB.${RESET}"
	exit 1
}
