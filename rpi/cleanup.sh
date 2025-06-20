#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Configuration
readonly IMAGES_DIR="${HOME}/.raspios-images"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [options]

Options:
  --all              Remove all images (base, final, and temp)
  --base             Remove only base image
  --final            Remove only final image
  --temp             Remove only temp images
  --qemu             Kill any running QEMU processes
  --ssh              Clean up SSH known_hosts for localhost:5555
  -h, --help         Show this help message

Examples:
  $0 --all           # Clean everything for fresh start
  $0 --qemu --ssh    # Clean up running processes and SSH
  $0 --base          # Remove base image to force rebuild
EOF
}

# Function to kill QEMU processes
kill_qemu() {
    printf "🔥 Killing QEMU processes...\n"
    if pgrep -f "qemu-system-aarch64" >/dev/null; then
        pkill -f "qemu-system-aarch64" || true
        sleep 2
        # Force kill if still running
        if pgrep -f "qemu-system-aarch64" >/dev/null; then
            pkill -9 -f "qemu-system-aarch64" || true
        fi
        printf "✅ QEMU processes terminated\n"
    else
        printf "ℹ️  No QEMU processes found\n"
    fi
}

# Function to clean SSH known_hosts
clean_ssh() {
    printf "🧹 Cleaning SSH known_hosts...\n"
    ssh-keygen -R "[localhost]:5555" 2>/dev/null || true
    printf "✅ SSH known_hosts cleaned\n"
}

# Function to remove images
remove_images() {
    local remove_base=false
    local remove_final=false
    local remove_temp=false
    local remove_all=false

    case "$1" in
        "all")
            remove_all=true
            ;;
        "base")
            remove_base=true
            ;;
        "final")
            remove_final=true
            ;;
        "temp")
            remove_temp=true
            ;;
    esac

    printf "🗑️  Removing images...\n"

    if [[ "$remove_all" == true ]] || [[ "$remove_base" == true ]]; then
        if [[ -f "${IMAGES_DIR}/panic-kiosk-base.img" ]]; then
            rm -f "${IMAGES_DIR}/panic-kiosk-base.img"
            printf "✅ Removed base image\n"
        fi
    fi

    if [[ "$remove_all" == true ]] || [[ "$remove_final" == true ]]; then
        if [[ -f "${IMAGES_DIR}/panic-kiosk.img" ]]; then
            rm -f "${IMAGES_DIR}/panic-kiosk.img"
            printf "✅ Removed final image\n"
        fi
    fi

    if [[ "$remove_all" == true ]] || [[ "$remove_temp" == true ]]; then
        if [[ -f "${IMAGES_DIR}/panic-kiosk-temp.img" ]]; then
            rm -f "${IMAGES_DIR}/panic-kiosk-temp.img"
            printf "✅ Removed temp image\n"
        fi
    fi

    if [[ "$remove_all" == true ]]; then
        # Remove any other panic-kiosk images
        find "${IMAGES_DIR}" -name "panic-kiosk*.img" -type f -delete 2>/dev/null || true
        printf "✅ Removed any other panic-kiosk images\n"
    fi
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            remove_images "all"
            shift
            ;;
        --base)
            remove_images "base"
            shift
            ;;
        --final)
            remove_images "final"
            shift
            ;;
        --temp)
            remove_images "temp"
            shift
            ;;
        --qemu)
            kill_qemu
            shift
            ;;
        --ssh)
            clean_ssh
            shift
            ;;
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

printf "\n🎉 Cleanup complete!\n"
