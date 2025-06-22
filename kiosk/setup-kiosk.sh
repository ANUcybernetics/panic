#!/bin/bash

# Raspberry Pi 5 Kiosk Mode Setup Script using rpi-imager
# This script uses rpi-imager CLI to configure and burn a Raspberry Pi OS image for kiosk mode
# Usage: ./setup-kiosk.sh <kiosk-url> <wifi-ssid> <wifi-username> <wifi-password>

set -e  # Exit on any error

# AIDEV-NOTE: Modern RPi5 kiosk setup using rpi-imager CLI with JSON config and enterprise WiFi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/work"
RPI_IMAGER_PATH="/Applications/Raspberry Pi Imager.app/Contents/MacOS/rpi-imager"
OS_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz"

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

    # Check for rpi-imager
    if [ ! -f "$RPI_IMAGER_PATH" ]; then
        log_error "Raspberry Pi Imager not found at: $RPI_IMAGER_PATH"
        log_info "Please install Raspberry Pi Imager from: https://www.raspberrypi.com/software/"
        exit 1
    fi

    # Check for required commands
    for tool in diskutil; do
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
    cd "$WORK_DIR"
}

# Create rpi-imager JSON configuration
create_config_json() {
    log_info "Creating rpi-imager configuration..."

    # Create the JSON configuration file
    cat > config.json << EOF
{
    "version": "1.7.5",
    "hostname": "$HOSTNAME",
    "ssh": {
        "enabled": true,
        "passwordAuthentication": true
    },
    "user": {
        "name": "$USERNAME",
        "password": "$DEFAULT_PASSWORD"
    },
    "wlan": {
        "ssid": "$WIFI_SSID",
        "username": "$WIFI_USERNAME",
        "password": "$WIFI_PASSWORD",
        "keyMgmt": "WPA-EAP",
        "eapMethod": "PEAP",
        "phase2Method": "MSCHAPV2"
    },
    "locale": {
        "keyboard": "us",
        "timezone": "America/New_York"
    },
    "firstRunScript": "firstrun.sh"
}
EOF

    log_success "Configuration JSON created"
}

# Create first-boot script for kiosk setup
create_firstrun_script() {
    log_info "Creating first-boot kiosk setup script..."

    cat > firstrun.sh << 'FIRSTRUN_EOF'
#!/bin/bash

# First-run script for Raspberry Pi OS Kiosk Mode
# AIDEV-NOTE: Enhanced firstrun.sh with proper error handling and logging

set -e

KIOSK_URL="__KIOSK_URL__"
USERNAME="__USERNAME__"
LOGFILE="/var/log/kiosk-setup.log"

# Logging function
log_setup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

log_setup "Starting kiosk setup for user: $USERNAME"
log_setup "Target URL: $KIOSK_URL"

# Update system packages
log_setup "Updating system packages..."
apt update && apt upgrade -y

# Install required packages for kiosk mode
log_setup "Installing kiosk mode packages..."
apt install -y \
    xserver-xorg \
    lightdm \
    openbox \
    chromium-browser \
    unclutter \
    xdotool

# Configure LightDM for auto-login
log_setup "Configuring auto-login..."
sed -i 's/#autologin-user=/autologin-user='${USERNAME}'/' /etc/lightdm/lightdm.conf
sed -i 's/#autologin-user-timeout=0/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf

# Create user directories
log_setup "Setting up user environment..."
mkdir -p /home/${USERNAME}/.config/openbox

# Create kiosk autostart script
log_setup "Creating kiosk autostart configuration..."
cat > /home/${USERNAME}/.config/openbox/autostart << AUTOSTART_EOF
#!/bin/bash

# Kiosk mode startup script
# AIDEV-NOTE: Comprehensive kiosk startup with audio support and error recovery

# Disable screensaver and power management
xset s off
xset -dpms
xset s noblank

# Hide cursor after 1 second of inactivity
unclutter -idle 1 -root &

# Set audio output to headphone jack (adjust as needed)
amixer cset numid=3 1

# Function to start Chromium with retry logic
start_chromium() {
    local url="\$1"
    local max_attempts=5
    local attempt=1

    while [ \$attempt -le \$max_attempts ]; do
        echo "Attempt \$attempt to start Chromium..."

        # Kill any existing Chromium processes
        pkill -f chromium-browser || true
        sleep 2

        # Start Chromium in kiosk mode
        chromium-browser \
            --kiosk \
            --noerrdialogs \
            --disable-infobars \
            --no-first-run \
            --enable-features=OverlayScrollbar \
            --disable-translate \
            --no-default-browser-check \
            --disable-extensions \
            --disable-plugins \
            --incognito \
            --disable-dev-shm-usage \
            --disable-gpu-sandbox \
            --no-sandbox \
            --autoplay-policy=no-user-gesture-required \
            --allow-running-insecure-content \
            --disable-web-security \
            --disable-features=VizDisplayCompositor \
            "\$url" &

        sleep 10

        # Check if Chromium is running
        if pgrep -f chromium-browser > /dev/null; then
            echo "Chromium started successfully"
            break
        else
            echo "Chromium failed to start, attempt \$attempt failed"
            ((attempt++))
            sleep 5
        fi
    done

    if [ \$attempt -gt \$max_attempts ]; then
        echo "Failed to start Chromium after \$max_attempts attempts"
        # Show error message on screen
        xterm -fullscreen -bg red -fg white -e "echo 'Kiosk startup failed. Check network connection.'; read" &
    fi
}

# Wait for network connectivity
echo "Waiting for network connectivity..."
for i in {1..30}; do
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "Network is available"
        break
    fi
    echo "Waiting for network... (\$i/30)"
    sleep 2
done

# Start Chromium with the specified URL
start_chromium "${KIOSK_URL}"

# Monitor and restart Chromium if it crashes
while true; do
    sleep 30
    if ! pgrep -f chromium-browser > /dev/null; then
        echo "Chromium not running, restarting..."
        start_chromium "${KIOSK_URL}"
    fi
done
AUTOSTART_EOF

chmod +x /home/${USERNAME}/.config/openbox/autostart

# Configure system to boot to graphical desktop
log_setup "Configuring boot target..."
systemctl set-default graphical.target
systemctl enable lightdm

# Disable unnecessary services to speed up boot
log_setup "Optimizing boot services..."
systemctl disable bluetooth
systemctl disable hciuart || true
systemctl disable triggerhappy || true

# Set proper ownership of user files
log_setup "Setting file permissions..."
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Configure audio for automatic output
log_setup "Configuring audio..."
# Add user to audio group
usermod -a -G audio ${USERNAME}

# Set up audio configuration
mkdir -p /home/${USERNAME}/.config/pulse
echo "load-module module-alsa-sink device=hw:0,0" > /home/${USERNAME}/.config/pulse/default.pa
echo "set-default-sink alsa_output.hw_0_0" >> /home/${USERNAME}/.config/pulse/default.pa
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/pulse

# Clean up - remove this script after successful run
log_setup "Cleaning up..."
rm -f /boot/firstrun.sh

log_setup "Kiosk setup completed successfully!"
log_setup "System will reboot into kiosk mode"

# Reboot to apply all changes
sleep 5
reboot
FIRSTRUN_EOF

    # Replace placeholders in the script
    sed -i '' "s|__KIOSK_URL__|$KIOSK_URL|g" firstrun.sh
    sed -i '' "s|__USERNAME__|$USERNAME|g" firstrun.sh
    chmod +x firstrun.sh

    log_success "First-boot kiosk script created"
}

# Find and verify SD card
find_sdcard() {
    log_info "Looking for SD card..."

    # List all disks and find removable media
    local disks=$(diskutil list | grep -E "^/dev/disk[0-9]+" | awk '{print $1}')
    local sdcard_found=""

    for disk in $disks; do
        local disk_info=$(diskutil info "$disk" 2>/dev/null || echo "")

        # Look for removable media that's likely an SD card
        if echo "$disk_info" | grep -q "Removable Media.*Yes" &&
           echo "$disk_info" | grep -qE "(SD|MMC|Generic|USB)"; then
            sdcard_found="$disk"
            break
        fi
    done

    if [ -z "$sdcard_found" ]; then
        log_error "No SD card found"
        log_info "Please insert an SD card and try again"
        log_info "Available disks:"
        diskutil list
        exit 1
    fi

    SDCARD_DEVICE="$sdcard_found"
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

# Use rpi-imager to configure and burn the image
burn_image() {
    log_info "Using rpi-imager to configure and burn image..."
    log_info "This process may take several minutes..."

    # Unmount the SD card if mounted
    diskutil unmountDisk "$SDCARD_DEVICE" || true

    # Use rpi-imager CLI to write the configured image
    "$RPI_IMAGER_PATH" --cli \
        --config config.json \
        --first-run-script firstrun.sh \
        "$OS_URL" \
        "$SDCARD_DEVICE"

    if [ $? -eq 0 ]; then
        log_success "Image configured and burned successfully!"
    else
        log_error "Failed to burn image with rpi-imager"
        exit 1
    fi

    # Eject the SD card
    diskutil eject "$SDCARD_DEVICE"
    log_success "SD card ejected. Ready to use in Raspberry Pi!"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    cd "$SCRIPT_DIR"
    rm -rf "$WORK_DIR" 2>/dev/null || true
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    log_info "Raspberry Pi 5 Kiosk Mode Setup (rpi-imager version)"
    log_info "====================================================="

    check_macos
    check_arguments "$@"
    check_dependencies
    setup_workspace
    create_config_json
    create_firstrun_script
    find_sdcard
    burn_image

    log_success "Setup completed successfully!"
    log_info ""
    log_info "Your Raspberry Pi 5 kiosk is ready!"
    log_info "=================================="
    log_info "Insert the SD card into your Raspberry Pi 5 and power it on."
    log_info ""
    log_info "The Pi will:"
    log_info "  1. Boot and run the first-time setup automatically"
    log_info "  2. Install required kiosk software"
    log_info "  3. Configure auto-login and kiosk mode"
    log_info "  4. Reboot into full-screen browser displaying: $KIOSK_URL"
    log_info ""
    log_info "Configuration:"
    log_info "  Hostname: $HOSTNAME.local"
    log_info "  Username: $USERNAME"
    log_info "  Password: $DEFAULT_PASSWORD"
    log_info "  WiFi SSID: $WIFI_SSID"
    log_info "  SSH: Enabled"
    log_info ""
    log_info "The initial setup may take 5-10 minutes on first boot."
    log_info "Setup logs are available at: /var/log/kiosk-setup.log"
}

# Run main function with all arguments
main "$@"
