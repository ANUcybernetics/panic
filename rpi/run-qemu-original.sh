#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Configuration
readonly IMAGES_DIR="${HOME}/.raspios-images"
readonly QEMU_MEMORY="1G"
readonly QEMU_CPU="cortex-a53"
readonly QEMU_CORES="4"
readonly SSH_KEY_NAME="panic_rpi_ssh"
readonly SSH_KEY_PATH="${HOME}/.ssh/${SSH_KEY_NAME}"

readonly IMAGE_NAME="panic-kiosk.img"
readonly IMAGE_PATH="${IMAGES_DIR}/${IMAGE_NAME}"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -h, --help         Show this help message

Examples:
  $0                 # Run in graphic mode
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf "Error: Unknown option '$1'\n" >&2
            usage
            exit 1
            ;;
    esac
done

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

# Check if QEMU is installed
if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
    printf "Error: qemu-system-aarch64 not found\n" >&2
    printf "Install with: brew install qemu\n" >&2
    exit 1
fi

# AIDEV-NOTE: Extract kernel and DTB directly from the Pi image for compatibility
readonly FIRMWARE_DIR="${IMAGES_DIR}/firmware"
readonly KERNEL_FILE="${FIRMWARE_DIR}/kernel8.img"
readonly DTB_FILE="${FIRMWARE_DIR}/bcm2710-rpi-3-b.dtb"

# Create firmware directory
mkdir -p "${FIRMWARE_DIR}"

# Extract kernel and DTB files from the image if not already present
if [[ ! -f "${KERNEL_FILE}" ]] || [[ ! -f "${DTB_FILE}" ]]; then
    printf "Extracting kernel and DTB files from Raspberry Pi image...\n"

    # Mount the image to extract firmware files
    printf "Mounting image to extract firmware...\n"
    DISK_DEVICE=$(hdiutil attach "${IMAGE_PATH}" | grep -E '^/dev/disk[0-9]+' | head -1 | awk '{print $1}')

    if [[ -z "${DISK_DEVICE}" ]]; then
        printf "Error: Could not attach image for firmware extraction\n" >&2
        exit 1
    fi

    # Find boot partition mount point
    BOOT_MOUNT=""
    sleep 2
    for mount in /Volumes/*; do
        if [[ -f "${mount}/config.txt" ]]; then
            BOOT_MOUNT="${mount}"
            break
        fi
    done

    if [[ -z "${BOOT_MOUNT}" ]]; then
        printf "Error: Could not find boot partition for firmware extraction\n" >&2
        hdiutil detach "${DISK_DEVICE}" || true
        exit 1
    fi

    # Copy kernel and DTB files
    if [[ -f "${BOOT_MOUNT}/kernel8.img" ]]; then
        cp "${BOOT_MOUNT}/kernel8.img" "${KERNEL_FILE}"
        chmod 755 "${KERNEL_FILE}"
        printf "Extracted kernel8.img\n"
    else
        printf "Error: kernel8.img not found in boot partition\n" >&2
        hdiutil detach "${DISK_DEVICE}" || true
        exit 1
    fi

    if [[ -f "${BOOT_MOUNT}/bcm2710-rpi-3-b.dtb" ]]; then
        cp "${BOOT_MOUNT}/bcm2710-rpi-3-b.dtb" "${DTB_FILE}"
        chmod 755 "${DTB_FILE}"
        printf "Extracted bcm2710-rpi-3-b.dtb\n"
    else
        printf "Error: bcm2710-rpi-3-b.dtb not found in boot partition\n" >&2
        hdiutil detach "${DISK_DEVICE}" || true
        exit 1
    fi

    # Unmount the image
    hdiutil detach "${DISK_DEVICE}"
    printf "Firmware files extracted successfully\n"
fi

printf "Starting Raspberry Pi image in QEMU...\n"
printf "Image: %s\n" "${IMAGE_PATH}"
printf "Memory: %s\n" "${QEMU_MEMORY}"
printf "CPU: %s (cores: %s)\n" "${QEMU_CPU}" "${QEMU_CORES}"
printf "Kernel: %s\n" "${KERNEL_FILE}"
printf "DTB: %s\n" "${DTB_FILE}"
printf "\nPress Ctrl+C to stop the virtual machine\n"
printf "SSH will be forwarded to localhost:5555\n"
printf "SSH command: ssh -i %s -p 5555 panic@localhost\n" "${SSH_KEY_PATH}"
printf "The Pi desktop should appear in the QEMU window once booted\n\n"
# Build QEMU command parameters
exec qemu-system-aarch64 \
    -machine raspi3b \
    -cpu "${QEMU_CPU}" \
    -smp "${QEMU_CORES}" \
    -m "${QEMU_MEMORY}" \
    -kernel "${KERNEL_FILE}" \
    -dtb "${DTB_FILE}" \
    -drive file="${IMAGE_PATH}",format=raw,if=sd \
    -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootdelay=1" \
    -netdev user,id=net0,hostfwd=tcp::5555-:22 \
    -device usb-net,netdev=net0 \
    -no-reboot \
    -usbdevice keyboard \
    -usbdevice mouse \
    -display cocoa \
    -serial stdio
