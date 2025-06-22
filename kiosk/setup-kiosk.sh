#!/bin/bash

# Raspberry Pi 5 Kiosk Mode Setup Script
# This script downloads, configures, and burns a Raspberry Pi OS image for kiosk mode
# Usage: ./setup-kiosk.sh <kiosk-url> <wifi-ssid> <wifi-username> <wifi-password>

set -e  # Exit on any error

# AIDEV-NOTE: Simplified RPi5 kiosk setup with enterprise WiFi and image caching

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/work"
CACHE_DIR="${HOME}/.raspios-images"
IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64-lite.img.xz"

# Parse image file name from URL
IMAGE_FILE=$(basename "$IMAGE_URL")

# Parse extracted image name by removing compression extensions
IMAGE_EXTRACTED=$(basename "$IMAGE_FILE" .xz)
if [[ "$IMAGE_EXTRACTED" == *.gz ]]; then
    IMAGE_EXTRACTED=$(basename "$IMAGE_EXTRACTED" .gz)
fi

HOSTNAME="pi-kiosk"
USERNAME="kiosk"
DEFAULT_PASSWORD="raspberry"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS. Please adapt for your OS."
        exit 1
    fi
}

# Check required arguments
check_arguments() {
    if [ $# -ne 4 ]; then
        log_error "Usage: $0 <kiosk-url> <wifi-ssid> <wifi-username> <wifi-password>"
        log_info "Example: $0 https://cybernetics.anu.edu.au MyWiFi myuser mypass"
        exit 1
    fi

    KIOSK_URL="$1"
    WIFI_SSID="$2"
    WIFI_USERNAME="$3"
    WIFI_PASSWORD="$4"

    log_info "Kiosk URL: $KIOSK_URL"
    log_info "WiFi SSID: $WIFI_SSID"
    log_info "WiFi Username: $WIFI_USERNAME"
}

# Check required tools
check_dependencies() {
    local missing_tools=()

    # Check for required commands
    for tool in curl diskutil hdiutil; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing dependencies and try again."
        exit 1
    fi
}

# Create work directories
setup_workspace() {
    log_info "Setting up workspace..."
    mkdir -p "$WORK_DIR"
    mkdir -p "$CACHE_DIR"
    cd "$WORK_DIR"
}

# Download or use cached Raspberry Pi OS image
download_image() {
    local cached_image="$CACHE_DIR/$IMAGE_FILE"

    if [ -f "$cached_image" ]; then
        log_success "Using cached image: $cached_image"
        cp "$cached_image" "$IMAGE_FILE"
        return
    fi

    log_info "Downloading Raspberry Pi OS Lite image..."
    curl -L -o "$IMAGE_FILE" "$IMAGE_URL"

    # Cache the downloaded image
    cp "$IMAGE_FILE" "$cached_image"
    log_success "Image downloaded and cached successfully"
}

# Extract image if compressed
extract_image() {
    log_info "Extracting image..."

    if [ -f "$IMAGE_EXTRACTED" ]; then
        log_warning "Extracted image already exists. Skipping extraction."
        return
    fi

    if [[ "$IMAGE_FILE" == *.xz ]]; then
        xz -d -k "$IMAGE_FILE"
        mv "${IMAGE_FILE%.xz}" "$IMAGE_EXTRACTED"
    else
        cp "$IMAGE_FILE" "$IMAGE_EXTRACTED"
    fi

    log_success "Image extracted successfully"
}

# Mount the image for modification
mount_image() {
    log_info "Mounting image for configuration..."

    # Attach the image to a device
    LOOP_DEVICE=$(hdiutil attach -nomount "$IMAGE_EXTRACTED" | head -1 | awk '{print $1}')

    if [ -z "$LOOP_DEVICE" ]; then
        log_error "Failed to attach image"
        exit 1
    fi

    log_info "Image attached to $LOOP_DEVICE"

    # Create mount point for boot partition only
    mkdir -p boot

    # Mount boot partition (FAT32)
    mount -t msdos "${LOOP_DEVICE}s1" boot
}

# Configure the image for kiosk mode
configure_image() {
    log_info "Configuring image for kiosk mode..."

    # Enable SSH
    touch boot/ssh
    log_info "SSH enabled"

    # Configure user account
    echo "${USERNAME}:$(echo "$DEFAULT_PASSWORD" | openssl passwd -6 -stdin)" > boot/userconf.txt
    log_info "User account configured: $USERNAME"

    # Configure enterprise WiFi
    cat > boot/wpa_supplicant.conf << EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$WIFI_SSID"
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="$WIFI_USERNAME"
    password="$WIFI_PASSWORD"
    phase2="auth=MSCHAPV2"
}
EOF
    log_info "Enterprise WiFi configured for SSID: $WIFI_SSID"

    # Configure boot options
    echo "dtoverlay=disable-bt" >> boot/config.txt
    log_info "Bluetooth disabled"

    # Configure cmdline for faster boot
    if [ -f boot/cmdline.txt ]; then
        sed -i '' 's/$/ quiet splash/' boot/cmdline.txt
    fi

    # Create first-boot configuration script
    log_info "Creating first-boot configuration script..."
    create_firstboot_script
}



# Create first-boot script for systems where root partition can't be mounted
create_firstboot_script() {
    # Create user configuration
    cat > boot/userconf.txt << EOF
${USERNAME}:$(echo "$DEFAULT_PASSWORD" | openssl passwd -6 -stdin)
EOF

    # Create firstrun.sh script using Raspberry Pi OS built-in mechanism
    cat > boot/firstrun.sh << 'FIRSTRUN_EOF'
#!/bin/bash

# First-run script for Raspberry Pi OS
# AIDEV-NOTE: This script uses the built-in firstrun.sh mechanism for reliable first-boot setup

set -e

KIOSK_URL="__KIOSK_URL__"
USERNAME="__USERNAME__"

# Update system
apt update && apt upgrade -y

# Install required packages for kiosk mode
apt install -y xserver-xorg lightdm openbox chromium-browser unclutter

# Configure auto-login
sed -i 's/#autologin-user=/autologin-user='${USERNAME}'/' /etc/lightdm/lightdm.conf
sed -i 's/#autologin-user-timeout=0/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf

# Create openbox configuration directory
mkdir -p /home/${USERNAME}/.config/openbox

# Create kiosk autostart script
cat > /home/${USERNAME}/.config/openbox/autostart << AUTOSTART_EOF
#!/bin/bash

# Disable screensaver and power management
xset s off
xset -dpms
xset s noblank

# Hide cursor after 1 second of inactivity
unclutter -idle 1 &

# Start Chromium in kiosk mode
chromium-browser --kiosk --noerrdialogs --disable-infobars --no-first-run --enable-features=OverlayScrollbar --disable-translate --no-default-browser-check --disable-extensions --disable-plugins --incognito --disable-dev-shm-usage "${KIOSK_URL}" &
AUTOSTART_EOF

chmod +x /home/${USERNAME}/.config/openbox/autostart

# Configure system to boot to graphical desktop
systemctl set-default graphical.target
systemctl enable lightdm

# Set proper ownership of user files
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Clean up - remove this script after successful run
rm -f /boot/firstrun.sh

echo "Kiosk setup completed successfully"
FIRSTRUN_EOF

    # Replace placeholders in the script
    sed -i '' "s|__KIOSK_URL__|$KIOSK_URL|g" boot/firstrun.sh
    sed -i '' "s|__USERNAME__|$USERNAME|g" boot/firstrun.sh
    chmod +x boot/firstrun.sh

    log_info "First-boot kiosk configuration created using firstrun.sh"
}

# Unmount the image
unmount_image() {
    log_info "Unmounting image..."

    # Unmount boot partition
    if mountpoint -q boot 2>/dev/null; then
        umount boot
    fi

    # Detach the image
    if [ -n "$LOOP_DEVICE" ]; then
        hdiutil detach "$LOOP_DEVICE"
    fi

    log_success "Image unmounted"
}

# Find and verify SD card
find_sdcard() {
    log_info "Looking for SD card in SDXC Reader..."

    # List all disks and find the SDXC reader
    local disks=$(diskutil list | grep -E "disk[0-9]" | awk '{print $1}')
    local sdcard_found=""

    for disk in $disks; do
        local disk_info=$(diskutil info "$disk" 2>/dev/null || echo "")
        if echo "$disk_info" | grep -q "SDXC Reader"; then
            sdcard_found="$disk"
            break
        fi
    done

    if [ -z "$sdcard_found" ]; then
        log_error "No SD card found in SDXC Reader"
        log_info "Please insert an SD card and try again"
        log_info "Available disks:"
        diskutil list
        exit 1
    fi

    # Handle case where disk path already includes /dev/
    if [[ "$sdcard_found" == /dev/* ]]; then
        SDCARD_DEVICE="$sdcard_found"
    else
        SDCARD_DEVICE="/dev/$sdcard_found"
    fi
    log_success "Found SD card: $SDCARD_DEVICE"

    # Show SD card info
    diskutil info "$SDCARD_DEVICE"

    # Confirm with user
    echo
    log_warning "This will ERASE ALL DATA on $SDCARD_DEVICE"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Operation cancelled"
        exit 0
    fi
}

# Burn image to SD card
burn_image() {
    log_info "Burning image to SD card..."

    # Unmount the SD card if mounted
    diskutil unmountDisk "$SDCARD_DEVICE"

    # Use dd to write the image
    log_info "Writing image to $SDCARD_DEVICE (this may take several minutes)..."

    # Use pv for progress if available
    if command -v pv &> /dev/null; then
        pv "$IMAGE_EXTRACTED" | sudo dd of="$SDCARD_DEVICE" bs=1M
    else
        sudo dd if="$IMAGE_EXTRACTED" of="$SDCARD_DEVICE" bs=1M status=progress
    fi

    # Sync to ensure all data is written
    sync

    log_success "Image burned successfully!"

    # Eject the SD card
    diskutil eject "$SDCARD_DEVICE"
    log_success "SD card ejected. Ready to use in Raspberry Pi!"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."

    # Unmount if still mounted
    if mountpoint -q boot 2>/dev/null; then
        umount boot 2>/dev/null || true
    fi

    # Detach image if still attached
    if [ -n "$LOOP_DEVICE" ]; then
        hdiutil detach "$LOOP_DEVICE" 2>/dev/null || true
    fi

    # Remove temporary directories
    rm -rf boot 2>/dev/null || true
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    log_info "Raspberry Pi 5 Kiosk Mode Setup"
    log_info "================================"

    check_macos
    check_arguments "$@"
    check_dependencies
    setup_workspace
    download_image
    extract_image
    mount_image
    configure_image
    unmount_image
    find_sdcard
    burn_image

    log_success "Setup completed successfully!"
    log_info "Insert the SD card into your Raspberry Pi 5 and power it on."
    log_info "The Pi will boot into kiosk mode displaying: $KIOSK_URL"
    log_info ""
    log_info "Default login credentials:"
    log_info "  Username: $USERNAME"
    log_info "  Password: $DEFAULT_PASSWORD"
    log_info "  Hostname: $HOSTNAME.local"
    log_info ""
    log_info "SSH is enabled for remote access if needed."
}

# Run main function with all arguments
main "$@"
