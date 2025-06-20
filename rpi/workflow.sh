#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <command> <url> [options]

Commands:
  create-only <url>           Create customized image only
  test <url>                  Create image and test in QEMU
  burn <url>                  Create image and burn to SD card
  burn-existing <image_name>  Burn existing image to SD card
  test-existing <image_name>  Test existing image in QEMU
  list                        List available images

Options:
  --name <name>              Custom name for created image (default: auto-generated)

Environment Variables (required for create operations):
  WIFI_SSID                  WiFi network name
  WIFI_PASSWORD              WiFi network password

Examples:
  # Create and test in QEMU
  WIFI_SSID="MyNetwork" WIFI_PASSWORD="secret123" $0 test https://example.com

  # Create and burn to SD card
  WIFI_SSID="MyNetwork" WIFI_PASSWORD="secret123" $0 burn https://example.com --name my-kiosk

  # Test existing image
  $0 test-existing kiosk-20250101-120000.img

  # Burn existing image to SD card
  $0 burn-existing kiosk-20250101-120000.img

  # List available images
  $0 list
EOF
}

# Function to check if required environment variables are set
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

# Function to list available images
list_images() {
    local images_dir="${HOME}/.raspios-images"

    if [[ ! -d "${images_dir}" ]]; then
        printf "No images directory found at %s\n" "${images_dir}"
        return 0
    fi

    printf "Available images in %s:\n" "${images_dir}"
    printf "%-40s %10s %20s\n" "IMAGE NAME" "SIZE" "MODIFIED"
    printf "%-40s %10s %20s\n" "$(printf '%*s' 40 '' | tr ' ' '-')" "$(printf '%*s' 10 '' | tr ' ' '-')" "$(printf '%*s' 20 '' | tr ' ' '-')"

    if ls "${images_dir}"/*.img >/dev/null 2>&1; then
        for img in "${images_dir}"/*.img; do
            local basename_img=$(basename "$img")
            local size=$(ls -lh "$img" | awk '{print $5}')
            local modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$img" 2>/dev/null || stat -c "%y" "$img" 2>/dev/null | cut -d' ' -f1-2)
            printf "%-40s %10s %20s\n" "$basename_img" "$size" "$modified"
        done
    else
        printf "No .img files found\n"
    fi
}

# Function to create image
create_image() {
    local url="$1"
    local image_name="${2:-}"

    check_env_vars

    printf "🔨 Creating customized Raspberry Pi image...\n"
    printf "URL: %s\n" "$url"
    printf "WiFi: %s\n" "$WIFI_SSID"

    if [[ -n "$image_name" ]]; then
        "${SCRIPT_DIR}/create-image.sh" "$url" "$image_name"
        echo "$image_name"
    else
        local output
        output=$("${SCRIPT_DIR}/create-image.sh" "$url" 2>&1)
        printf "%s\n" "$output"
        # Extract image name from output (last line should contain the path)
        echo "$output" | grep "Custom image created successfully" | sed 's/.*\/\([^\/]*\.img\)$/\1/'
    fi
}

# Function to test image in QEMU
test_image() {
    local image_name="$1"

    printf "🖥️  Testing image in QEMU...\n"
    printf "Image: %s\n" "$image_name"
    printf "Note: The Pi desktop should appear in the QEMU window once booted\n"
    printf "      Press Ctrl+C to stop the virtual machine\n\n"

    "${SCRIPT_DIR}/run-qemu.sh" "$image_name"
}

# Function to burn image to SD card
burn_image() {
    local image_name="$1"

    printf "💾 Burning image to SD card...\n"
    printf "Image: %s\n" "$image_name"

    "${SCRIPT_DIR}/burn-sdcard.sh" "$image_name"
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    "create-only")
        if [[ $# -eq 0 ]]; then
            printf "Error: URL argument required\n" >&2
            usage
            exit 1
        fi

        URL="$1"
        shift

        IMAGE_NAME=""
        while [[ $# -gt 0 ]]; do
            case $1 in
                --name)
                    IMAGE_NAME="$2"
                    shift 2
                    ;;
                *)
                    printf "Error: Unknown option $1\n" >&2
                    usage
                    exit 1
                    ;;
            esac
        done

        create_image "$URL" "$IMAGE_NAME"
        ;;

    "test")
        if [[ $# -eq 0 ]]; then
            printf "Error: URL argument required\n" >&2
            usage
            exit 1
        fi

        URL="$1"
        shift

        IMAGE_NAME=""
        while [[ $# -gt 0 ]]; do
            case $1 in
                --name)
                    IMAGE_NAME="$2"
                    shift 2
                    ;;
                *)
                    printf "Error: Unknown option $1\n" >&2
                    usage
                    exit 1
                    ;;
            esac
        done

        CREATED_IMAGE=$(create_image "$URL" "$IMAGE_NAME")
        test_image "$CREATED_IMAGE"
        ;;

    "burn")
        if [[ $# -eq 0 ]]; then
            printf "Error: URL argument required\n" >&2
            usage
            exit 1
        fi

        URL="$1"
        shift

        IMAGE_NAME=""
        while [[ $# -gt 0 ]]; do
            case $1 in
                --name)
                    IMAGE_NAME="$2"
                    shift 2
                    ;;
                *)
                    printf "Error: Unknown option $1\n" >&2
                    usage
                    exit 1
                    ;;
            esac
        done

        CREATED_IMAGE=$(create_image "$URL" "$IMAGE_NAME")
        burn_image "$CREATED_IMAGE"
        ;;

    "test-existing")
        if [[ $# -eq 0 ]]; then
            printf "Error: Image name argument required\n" >&2
            usage
            exit 1
        fi

        test_image "$1"
        ;;

    "burn-existing")
        if [[ $# -eq 0 ]]; then
            printf "Error: Image name argument required\n" >&2
            usage
            exit 1
        fi

        burn_image "$1"
        ;;

    "list")
        list_images
        ;;

    *)
        printf "Error: Unknown command '$COMMAND'\n" >&2
        usage
        exit 1
        ;;
esac
