#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Configuration
readonly IMAGES_DIR="${HOME}/.raspios-images"
readonly QEMU_MEMORY="1G"
readonly QEMU_CPU="cortex-a72"

# Check for image argument
if [ $# -eq 0 ]; then
    printf "Error: Image name argument required\n" >&2
    printf "Usage: %s <image_name>\n" "$0" >&2
    printf "Example: %s kiosk-20250101-120000.img\n" "$0" >&2
    exit 1
fi

readonly IMAGE_NAME="$1"
readonly IMAGE_PATH="${IMAGES_DIR}/${IMAGE_NAME}"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    printf "Error: This script is designed for macOS\n" >&2
    exit 1
fi

# Check if image exists
if [[ ! -f "${IMAGE_PATH}" ]]; then
    printf "Error: Image not found at %s\n" "${IMAGE_PATH}" >&2
    printf "Available images in %s:\n" "${IMAGES_DIR}" >&2
    ls -la "${IMAGES_DIR}"/*.img 2>/dev/null || printf "No .img files found\n" >&2
    exit 1
fi

# Check if QEMU is installed
if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
    printf "Error: qemu-system-aarch64 not found\n" >&2
    printf "Install with: brew install qemu\n" >&2
    exit 1
fi

# AIDEV-NOTE: Need Raspberry Pi firmware files for proper boot
readonly FIRMWARE_DIR="${IMAGES_DIR}/firmware"
readonly KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/kernel8.img"
readonly DTB_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/versatile-pb-buster.dtb"

# Download firmware files if not present
mkdir -p "${FIRMWARE_DIR}"

if [[ ! -f "${FIRMWARE_DIR}/kernel8.img" ]]; then
    printf "Downloading Raspberry Pi kernel for QEMU...\n"
    curl -L -o "${FIRMWARE_DIR}/kernel8.img" "${KERNEL_URL}"
fi

if [[ ! -f "${FIRMWARE_DIR}/versatile-pb-buster.dtb" ]]; then
    printf "Downloading device tree blob for QEMU...\n"
    curl -L -o "${FIRMWARE_DIR}/versatile-pb-buster.dtb" "${DTB_URL}"
fi

printf "Starting Raspberry Pi image in QEMU...\n"
printf "Image: %s\n" "${IMAGE_PATH}"
printf "Memory: %s\n" "${QEMU_MEMORY}"
printf "CPU: %s\n" "${QEMU_CPU}"
printf "\nPress Ctrl+C to stop the virtual machine\n"
printf "The Pi desktop should appear in the QEMU window once booted\n\n"

# AIDEV-NOTE: Using raspi3b machine type with ARM Cortex-A72 for Raspberry Pi 4 compatibility
# VNC display allows viewing the desktop, SSH forwarding enables remote access
exec qemu-system-aarch64 \
    -machine raspi3b \
    -cpu "${QEMU_CPU}" \
    -m "${QEMU_MEMORY}" \
    -kernel "${FIRMWARE_DIR}/kernel8.img" \
    -dtb "${FIRMWARE_DIR}/versatile-pb-buster.dtb" \
    -drive format=raw,file="${IMAGE_PATH}" \
    -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1" \
    -netdev user,id=net0,hostfwd=tcp::5555-:22 \
    -device rtl8139,netdev=net0 \
    -display cocoa \
    -serial stdio \
    -no-reboot
