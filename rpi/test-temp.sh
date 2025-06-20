#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Simple QEMU test script to diagnose boot issues

# Configuration
readonly IMAGES_DIR="${HOME}/.raspios-images"
readonly IMAGE_PATH="${IMAGES_DIR}/panic-kiosk-temp.img"

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

printf "=== QEMU Diagnostics Test ===\n"
printf "Image: %s\n" "${IMAGE_PATH}"
printf "Image size: %s\n" "$(ls -lh "${IMAGE_PATH}" | awk '{print $5}')"

# Test 1: Basic virt machine boot
printf "\n=== Test 1: Basic virt machine (no Pi hardware) ===\n"
printf "This should boot the Linux kernel...\n"

timeout 60s qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 \
    -smp 2 \
    -m 1G \
    -drive file="${IMAGE_PATH}",format=raw,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::5555-:22 \
    -device virtio-net-pci,netdev=net0 \
    -nographic \
    -no-reboot \
    -monitor none \
    -serial stdio || printf "Test 1 completed (timeout or exit)\n"

printf "\n=== Test 1 Results ===\n"
printf "If you saw kernel boot messages, the image is good.\n"
printf "If you saw 'EFI' messages, the image has UEFI support.\n"
printf "If it hung or crashed immediately, there may be image corruption.\n"

printf "\n=== Test 2: Check image structure ===\n"
# Mount and check image structure
DISK_DEVICE=$(hdiutil attach "${IMAGE_PATH}" 2>/dev/null | grep -E '^/dev/disk[0-9]+' | head -1 | awk '{print $1}')

if [[ -n "${DISK_DEVICE}" ]]; then
    printf "Image mounted successfully as: %s\n" "${DISK_DEVICE}"

    # Check partitions
    printf "Partitions:\n"
    diskutil list "${DISK_DEVICE}" || true

    # Check boot partition
    BOOT_MOUNT=""
    for mount in /Volumes/*; do
        if [[ -f "${mount}/config.txt" ]]; then
            BOOT_MOUNT="${mount}"
            break
        fi
    done

    if [[ -n "${BOOT_MOUNT}" ]]; then
        printf "\nBoot partition found at: %s\n" "${BOOT_MOUNT}"
        printf "Boot files:\n"
        ls -la "${BOOT_MOUNT}" | head -10

        # Check for key files
        printf "\nKey files check:\n"
        [[ -f "${BOOT_MOUNT}/kernel8.img" ]] && printf "✅ kernel8.img found\n" || printf "❌ kernel8.img missing\n"
        [[ -f "${BOOT_MOUNT}/config.txt" ]] && printf "✅ config.txt found\n" || printf "❌ config.txt missing\n"
        [[ -f "${BOOT_MOUNT}/cmdline.txt" ]] && printf "✅ cmdline.txt found\n" || printf "❌ cmdline.txt missing\n"
        [[ -f "${BOOT_MOUNT}/panic_rpi_ssh.pub" ]] && printf "✅ SSH key found\n" || printf "❌ SSH key missing\n"

        # Check cmdline.txt content
        if [[ -f "${BOOT_MOUNT}/cmdline.txt" ]]; then
            printf "\ncmdline.txt content:\n"
            cat "${BOOT_MOUNT}/cmdline.txt"
            printf "\n"
        fi
    else
        printf "❌ Boot partition not found\n"
    fi

    # Unmount
    hdiutil detach "${DISK_DEVICE}" 2>/dev/null || true
else
    printf "❌ Could not mount image\n"
fi

printf "\n=== Test 3: Network connectivity test ===\n"
printf "Testing if port 5555 is available...\n"
if lsof -i :5555 >/dev/null 2>&1; then
    printf "❌ Port 5555 is already in use:\n"
    lsof -i :5555
else
    printf "✅ Port 5555 is available\n"
fi

printf "\n=== Test 4: Try Pi-specific machine ===\n"
printf "Testing with raspi3b machine (limited resources)...\n"

# Extract kernel if needed for Pi machine test
FIRMWARE_DIR="${IMAGES_DIR}/firmware"
KERNEL_FILE="${FIRMWARE_DIR}/kernel8.img"
DTB_FILE="${FIRMWARE_DIR}/bcm2710-rpi-3-b.dtb"

mkdir -p "${FIRMWARE_DIR}"

if [[ ! -f "${KERNEL_FILE}" ]]; then
    printf "Extracting kernel from image...\n"
    DISK_DEVICE=$(hdiutil attach "${IMAGE_PATH}" 2>/dev/null | grep -E '^/dev/disk[0-9]+' | head -1 | awk '{print $1}')

    if [[ -n "${DISK_DEVICE}" ]]; then
        BOOT_MOUNT=""
        for mount in /Volumes/*; do
            if [[ -f "${mount}/config.txt" ]]; then
                BOOT_MOUNT="${mount}"
                break
            fi
        done

        if [[ -n "${BOOT_MOUNT}" ]] && [[ -f "${BOOT_MOUNT}/kernel8.img" ]]; then
            cp "${BOOT_MOUNT}/kernel8.img" "${KERNEL_FILE}"
            printf "✅ Kernel extracted\n"
        fi

        if [[ -n "${BOOT_MOUNT}" ]] && [[ -f "${BOOT_MOUNT}/bcm2710-rpi-3-b.dtb" ]]; then
            cp "${BOOT_MOUNT}/bcm2710-rpi-3-b.dtb" "${DTB_FILE}"
            printf "✅ DTB extracted\n"
        fi

        hdiutil detach "${DISK_DEVICE}" 2>/dev/null || true
    fi
fi

if [[ -f "${KERNEL_FILE}" ]] && [[ -f "${DTB_FILE}" ]]; then
    printf "Testing Pi-specific boot...\n"

    timeout 30s qemu-system-aarch64 \
        -machine raspi3b \
        -cpu cortex-a53 \
        -smp 4 \
        -m 1G \
        -kernel "${KERNEL_FILE}" \
        -dtb "${DTB_FILE}" \
        -drive file="${IMAGE_PATH}",format=raw,if=sd \
        -append "rw root=/dev/mmcblk0p2 rootdelay=1 console=ttyAMA0,115200" \
        -netdev user,id=net0,hostfwd=tcp::5556-:22 \
        -device usb-net,netdev=net0 \
        -nographic \
        -no-reboot \
        -monitor none \
        -serial stdio || printf "Test 4 completed (timeout or exit)\n"
else
    printf "❌ Could not extract kernel/DTB for Pi test\n"
fi

printf "\n=== Diagnostics Complete ===\n"
printf "Summary:\n"
printf "  - If Test 1 showed boot messages: Image is bootable\n"
printf "  - If Test 2 found boot files: Image structure is correct\n"
printf "  - If Test 3 showed port available: Network setup should work\n"
printf "  - If Test 4 showed boot messages: Pi-specific emulation works\n"
printf "\nNext steps:\n"
printf "1. If tests show boot messages, try: ./run-qemu.sh --nographic\n"
printf "2. Wait longer for SSH (first boot installs packages)\n"
printf "3. Check ./ssh-qemu.sh test after 2-3 minutes\n"
