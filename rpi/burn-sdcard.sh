#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
# set -x           # Enable debugging output

# Configuration
readonly IMAGES_DIR="${HOME}/.raspios-images"

readonly IMAGE_NAME="panic-kiosk.img"
readonly IMAGE_PATH="${IMAGES_DIR}/${IMAGE_NAME}"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    printf "Error: This script is designed for macOS\n" >&2
    exit 1
fi

# Check if image exists
if [[ ! -f "${IMAGE_PATH}" ]]; then
    printf "Error: Image not found at %s\n" "${IMAGE_PATH}" >&2
    printf "Run './workflow.sh create <URL>' first to create the image\n" >&2
    exit 1
fi

# Find SD card device with name "Built In SDXC Reader"
printf "\nLooking for Built In SDXC Reader...\n"
SD_CARD=""
while IFS= read -r disk_line; do
    disk=$(echo "$disk_line" | awk '{print $1}')
    if diskutil info "$disk" 2>/dev/null | grep -qE "(internal|synthesized|APFS Container|APPLE SSD)"; then
        continue
    fi
    name=$(diskutil info "$disk" 2>/dev/null | grep "Device / Media Name" | awk -F: '{print $2}' | xargs)
    if [[ "$name" == "Built In SDXC Reader" ]]; then
        SD_CARD="$disk"
        break
    fi
done < <(diskutil list 2>/dev/null | grep -E "^/dev/disk[0-9]+")

if [[ -z "${SD_CARD}" ]]; then
    printf "Error: Built In SDXC Reader not found. Please insert an SD card.\n" >&2
    exit 1
fi

printf "Found Built In SDXC Reader: %s\n" "${SD_CARD}"

# Validate the entered path
if [[ ! -e "${SD_CARD}" ]]; then
    printf "Error: Device %s does not exist\n" "${SD_CARD}" >&2
    exit 1
fi

# Additional check to avoid system disks
if diskutil info "${SD_CARD}" 2>/dev/null | grep -qE "(internal.*APFS|synthesized|APPLE SSD)" >/dev/null; then
    printf "Error: %s appears to be a system disk. Please select an SD card.\n" "${SD_CARD}" >&2
    exit 1
fi

# Show SD card info for confirmation
printf "\nSD Card Information:\n"
diskutil info "${SD_CARD}" | grep -E "(Device / Media Name|Total Size|File System)"

printf "\nWARNING: This will completely erase the SD card at %s\n" "${SD_CARD}"
printf "Image to write: %s\n" "${IMAGE_PATH}"
printf "Image size: %s\n" "$(ls -lh "${IMAGE_PATH}" | awk '{print $5}')"

# Confirmation prompt
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "Operation cancelled.\n"
    exit 0
fi

# Unmount SD card
printf "Unmounting SD card...\n"
diskutil unmountDisk "${SD_CARD}"

# Write image to SD card
printf "Writing image to SD card (this may take several minutes)...\n"
printf "Progress will be shown below...\n\n"
sudo dd if="${IMAGE_PATH}" of="${SD_CARD}" bs=4m status=progress

# Eject SD card
printf "\nEjecting SD card...\n"
diskutil eject "${SD_CARD}"

printf "✅ SD card creation complete!\n"
printf "The SD card has been ejected and is ready for use in a Raspberry Pi.\n"
printf "First boot will take longer as it installs desktop components and configures the kiosk.\n"
