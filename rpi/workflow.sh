#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <command> [url]

Commands:
  prepare-base         Create prepared base image (one-time setup)
  create <url>         Create final image from prepared base
  test <url>           Create final image and test in QEMU
  burn <url>           Create final image and burn to SD card
  test-only            Test existing panic-kiosk.img in QEMU
  burn-only            Burn existing panic-kiosk.img to SD card

Environment Variables (required for prepare-base):
  WIFI_SSID       WiFi network name
  WIFI_PASSWORD   WiFi network password

Two-Stage Workflow:
  # One-time: Create prepared base image with packages installed
  WIFI_SSID="MyNetwork" WIFI_PASSWORD="secret123" $0 prepare-base

  # Fast: Create final images from prepared base
  $0 create https://example.com
  $0 test https://example.com
  $0 burn https://example.com

  # Test existing image (graphic mode)
  $0 test-only

  # Test existing image (nographic mode)
  $0 test-only-nographic

  # Burn existing image to SD card
  $0 burn-only
EOF
}

# Function to check if required environment variables are set for base image preparation
check_env_vars() {
    if [[ -z "${WIFI_SSID:-}" ]]; then
        printf "Error: WIFI_SSID environment variable is required\n" >&2
        exit 1
    fi

    if [[ -z "${WIFI_PASSWORD:-}" ]]; then
        printf "Error: WIFI_PASSWORD environment variable is required\n" >&2
        exit 1
    fi
}

# Function to prepare base image
prepare_base_image() {
    check_env_vars

    printf "🔨 Preparing base image (one-time setup)...\n"
    printf "This will install packages in QEMU and may take 15-30 minutes\n"
    printf "WiFi: %s\n" "$WIFI_SSID"

    "${SCRIPT_DIR}/prepare-base-image.sh"
}

# Function to create final image from base
create_final_image() {
    local url="$1"

    printf "🔨 Creating final panic-kiosk.img from prepared base...\n"
    printf "URL: %s\n" "$url"

    "${SCRIPT_DIR}/create-final-image.sh" "$url"
}

# Function to test image in QEMU
test_image() {
    printf "🖥️  Testing panic-kiosk.img in QEMU...\n"
    printf "Note: The Pi desktop should appear in the QEMU window once booted\n"
    printf "      Press Ctrl+C to stop the virtual machine\n\n"

    "${SCRIPT_DIR}/run-qemu.sh"
}

# Function to burn image to SD card
burn_image() {
    printf "💾 Burning panic-kiosk.img to SD card...\n"

    "${SCRIPT_DIR}/burn-sdcard.sh"
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    "prepare-base")
        prepare_base_image
        ;;

    "create")
        if [[ $# -eq 0 ]]; then
            printf "Error: URL argument required\n" >&2
            usage
            exit 1
        fi

        create_final_image "$1"
        ;;

    "test")
        if [[ $# -eq 0 ]]; then
            printf "Error: URL argument required\n" >&2
            usage
            exit 1
        fi

        create_final_image "$1"
        test_image
        ;;

    "burn")
        if [[ $# -eq 0 ]]; then
            printf "Error: URL argument required\n" >&2
            usage
            exit 1
        fi

        create_final_image "$1"
        burn_image
        ;;

    "test-only")
        test_image
        ;;

    "burn-only")
        burn_image
        ;;

    "-h"|"--help"|"help")
        usage
        exit 0
        ;;
    *)
        printf "Error: Unknown command '$COMMAND'\n" >&2
        usage
        exit 1
        ;;
esac
