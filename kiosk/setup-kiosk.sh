#!/bin/bash

# Raspberry Pi 5 Kiosk Mode Setup Script
# This script downloads, configures, and burns a Raspberry Pi OS image for kiosk mode
# Usage: ./setup-kiosk.sh <kiosk-url> [wifi-ssid] [wifi-password]

set -e  # Exit on any error

# AIDEV-NOTE: Main script for automated RPi5 kiosk image creation and SD card burning

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/work"
IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64-lite.img.xz"
IMAGE_FILE="raspios-lite-arm64.img.xz"
IMAGE_EXTRACTED="raspios-lite-arm64.img"
SDCARD_DEVICE="/dev/disk2"  # Common macOS SDXC Reader location
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
    if [ $# -lt 1 ]; then
        log_error "Usage: $0 <kiosk-url> [wifi-ssid] [wifi-password]"
        log_info "Example: $0 https://example.com MyWiFi MyPassword"
        exit 1
    fi

    KIOSK_URL="$1"
    WIFI_SSID="${2:-}"
    WIFI_PASSWORD="${3:-}"

    log_info "Kiosk URL: $KIOSK_URL"
    if [ -n "$WIFI_SSID" ]; then
        log_info "WiFi SSID: $WIFI_SSID"
    fi
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

# Create work directory
setup_workspace() {
    log_info "Setting up workspace..."
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
}

# Download Raspberry Pi OS image
download_image() {
    log_info "Downloading Raspberry Pi OS Lite image..."

    if [ -f "$IMAGE_FILE" ]; then
        log_warning "Image file already exists. Skipping download."
        return
    fi

    curl -L -o "$IMAGE_FILE" "$IMAGE_URL"
    log_success "Image downloaded successfully"
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

    # Create mount points
    mkdir -p boot root

    # Mount boot partition (FAT32)
    mount -t msdos "${LOOP_DEVICE}s1" boot

    # Mount root partition (ext4) - requires additional tools on macOS
    if command -v fuse-ext2 &> /dev/null; then
        fuse-ext2 "${LOOP_DEVICE}s2" root -o rw+
    else
        log_warning "fuse-ext2 not found. Some configurations will be skipped."
        log_info "Install fuse-ext2 with: brew install fuse-ext2"
    fi
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

    # Configure WiFi if provided
    if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASSWORD" ]; then
        cat > boot/wpa_supplicant.conf << EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
}
EOF
        log_info "WiFi configured for SSID: $WIFI_SSID"
    fi

    # Configure boot options
    echo "dtoverlay=disable-bt" >> boot/config.txt
    log_info "Bluetooth disabled"

    # Configure cmdline for faster boot
    if [ -f boot/cmdline.txt ]; then
        sed -i '' 's/$/ quiet splash/' boot/cmdline.txt
    fi

    # If root partition is mounted, configure system files
    if mountpoint -q root; then
        configure_root_partition
    else
        log_warning "Root partition not mounted. Creating post-boot configuration script."
        create_firstboot_script
    fi
}

# Configure root partition directly
configure_root_partition() {
    log_info "Configuring root partition..."

    # Create kiosk configuration script
    cat > root/home/${USERNAME}/setup-kiosk-mode.sh << 'EOF'
#!/bin/bash

# Post-boot kiosk configuration script
# AIDEV-NOTE: This script runs on first boot to complete kiosk setup

set -e

KIOSK_URL="__KIOSK_URL__"
USERNAME="__USERNAME__"

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y chromium-browser wtype openbox lightdm

# Configure auto-login
sudo sed -i 's/#autologin-user=/autologin-user='${USERNAME}'/' /etc/lightdm/lightdm.conf
sudo sed -i 's/#autologin-user-timeout=0/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf

# Create openbox autostart
mkdir -p /home/${USERNAME}/.config/openbox
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

# Configure system to boot to desktop
sudo systemctl set-default graphical.target
sudo systemctl enable lightdm

# Create security hardening script
cat > /home/${USERNAME}/harden-system.sh << HARDEN_EOF
#!/bin/bash

# Security hardening for kiosk mode
# AIDEV-NOTE: Optional security hardening - run manually if needed

# Disable USB ports
echo '1-1' | sudo tee /sys/bus/usb/drivers/usb/unbind

# Disable Ethernet
sudo ifconfig eth0 down

# Make changes persistent
sudo tee -a /etc/rc.local > /dev/null << RC_EOF

# Disable USB and Ethernet for kiosk security
echo '1-1' | sudo tee /sys/bus/usb/drivers/usb/unbind
sudo ifconfig eth0 down

RC_EOF

echo "Security hardening applied. Reboot to take effect."
HARDEN_EOF

chmod +x /home/${USERNAME}/harden-system.sh

# Set ownership
sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

echo "Kiosk mode configuration completed!"
echo "The system will now reboot and start in kiosk mode."
echo "To apply security hardening, run: ~/harden-system.sh"

# Clean up - remove this script
rm -- "$0"

# Reboot to apply changes
sudo reboot
EOF

    # Replace placeholders
    sed -i '' "s|__KIOSK_URL__|$KIOSK_URL|g" root/home/${USERNAME}/setup-kiosk-mode.sh
    sed -i '' "s|__USERNAME__|$USERNAME|g" root/home/${USERNAME}/setup-kiosk-mode.sh

    chmod +x root/home/${USERNAME}/setup-kiosk-mode.sh

    # Create a service to run the setup script on first boot
    cat > root/etc/systemd/system/kiosk-setup.service << EOF
[Unit]
Description=Kiosk Mode Setup
After=network.target
Wants=network.target

[Service]
Type=oneshot
User=${USERNAME}
ExecStart=/home/${USERNAME}/setup-kiosk-mode.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Enable the service
    chroot root systemctl enable kiosk-setup.service

    log_success "Root partition configured"
}

# Create first-boot script for systems where root partition can't be mounted
create_firstboot_script() {
    # Create a script that will run on first boot
    cat > boot/firstboot.sh << EOF
#!/bin/bash

# First boot configuration script
# This will be executed automatically on first boot

# Enable service that will complete kiosk setup
systemctl enable ssh
systemctl start ssh

# Create setup script
cat > /tmp/complete-kiosk-setup.sh << 'SETUP_EOF'
#!/bin/bash

# Complete kiosk mode setup
sudo apt update && sudo apt upgrade -y
sudo apt install -y chromium-browser wtype openbox lightdm unclutter

# Configure auto-login
sudo sed -i 's/#autologin-user=/autologin-user=${USERNAME}/' /etc/lightdm/lightdm.conf
sudo sed -i 's/#autologin-user-timeout=0/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf

# Create openbox config
mkdir -p ~/.config/openbox
cat > ~/.config/openbox/autostart << 'AUTOSTART_EOF'
xset s off
xset -dpms
xset s noblank
unclutter -idle 1 &
chromium-browser --kiosk --noerrdialogs --disable-infobars --no-first-run --enable-features=OverlayScrollbar --disable-translate --no-default-browser-check --disable-extensions --disable-plugins --incognito --disable-dev-shm-usage "${KIOSK_URL}" &
AUTOSTART_EOF

chmod +x ~/.config/openbox/autostart

sudo systemctl set-default graphical.target
sudo systemctl enable lightdm

echo "Setup complete! Rebooting to kiosk mode..."
sleep 3
sudo reboot
SETUP_EOF

chmod +x /tmp/complete-kiosk-setup.sh

# Setup to run on next login
echo "/tmp/complete-kiosk-setup.sh" >> ~/.bashrc

rm -- "$0"
EOF

    # Replace placeholder
    sed -i '' "s/\${KIOSK_URL}/$KIOSK_URL/g" boot/firstboot.sh
    sed -i '' "s/\${USERNAME}/$USERNAME/g" boot/firstboot.sh

    chmod +x boot/firstboot.sh

    # Add to cmdline.txt to run on boot
    if [ -f boot/cmdline.txt ]; then
        echo " init=/boot/firstboot.sh" >> boot/cmdline.txt
    fi
}

# Unmount the image
unmount_image() {
    log_info "Unmounting image..."

    # Unmount partitions
    if mountpoint -q boot; then
        umount boot
    fi

    if mountpoint -q root; then
        umount root
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

    SDCARD_DEVICE="/dev/$sdcard_found"
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

    if mountpoint -q root 2>/dev/null; then
        umount root 2>/dev/null || true
    fi

    # Detach image if still attached
    if [ -n "$LOOP_DEVICE" ]; then
        hdiutil detach "$LOOP_DEVICE" 2>/dev/null || true
    fi

    # Remove temporary directories
    rm -rf boot root 2>/dev/null || true
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
