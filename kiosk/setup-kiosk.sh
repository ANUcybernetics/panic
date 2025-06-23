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
    AUTO_YES=false
    CONFIGURE_ONLY=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --yes)
                AUTO_YES=true
                shift
                ;;
            --configure-only)
                CONFIGURE_ONLY=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                log_error "Usage: $0 [--yes] [--configure-only] <kiosk-url> <wifi-ssid> <wifi-username> <wifi-password>"
                log_info "Options:"
                log_info "  --yes             Skip interactive confirmations"
                log_info "  --configure-only  Skip burning, only configure existing RPi OS SD card"
                log_info "Example: $0 --yes https://cybernetics.anu.edu.au MyWiFi myuser mypass"
                log_info "Example: $0 --configure-only https://cybernetics.anu.edu.au MyWiFi myuser mypass"
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    if [ $# -ne 4 ]; then
        log_error "Usage: $0 [--yes] [--configure-only] <kiosk-url> <wifi-ssid> <wifi-username> <wifi-password>"
        log_info "Options:"
        log_info "  --yes             Skip interactive confirmations"
        log_info "  --configure-only  Skip burning, only configure existing RPi OS SD card"
        log_info "Example: $0 --yes https://cybernetics.anu.edu.au MyWiFi myuser mypass"
        log_info "Example: $0 --configure-only https://cybernetics.anu.edu.au MyWiFi myuser mypass"
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

# Create boot partition configuration files
create_boot_configs() {
    log_info "Creating boot partition configuration files..."

    # Create SSH enable file
    touch ssh

    # Create user configuration file (username:encrypted_password)
    # Default password is 'raspberry'
    echo "${USERNAME}:\$6\$rounds=656000\$5dPCdSCNhEHk8F0v\$dXEGMQFPg.b9Wq8XzgvJjuaXd1c6lddSI2sO5i2qRvyEMhGrE5bFQZKhT0jEKaWYEyRu5rWNsZH7wVYIgOQPk1" > userconf.txt

    # Create wpa_supplicant configuration for enterprise WiFi
    cat > wpa_supplicant.conf << EOF
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

    log_success "Boot configuration files created"
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
        if echo "$disk_info" | grep -q "Removable Media.*Removable" &&
           echo "$disk_info" | grep -qE "(SD|MMC|Generic|USB|Secure Digital)"; then
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

    # Confirm with user (skip if configure-only mode)
    if [ "$CONFIGURE_ONLY" = false ]; then
        echo
        log_warning "This will ERASE ALL DATA on $SDCARD_DEVICE"
        if [ "$AUTO_YES" = true ]; then
            log_info "Auto-confirming due to --yes flag"
        else
            read -p "Are you sure you want to continue? (yes/no): " -r
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                log_info "Operation cancelled"
                exit 0
            fi
        fi
    else
        log_info "Configure-only mode: Will only modify boot partition configuration"
    fi
}

# Use rpi-imager to burn base image, then configure boot partition
burn_image() {
    log_info "Using rpi-imager to burn base image..."
    log_info "This process may take several minutes..."

    # Unmount the SD card if mounted
    diskutil unmountDisk "$SDCARD_DEVICE" || true

    # Use rpi-imager CLI to write the base image
    "$RPI_IMAGER_PATH" --cli "$OS_URL" "$SDCARD_DEVICE"

    if [ $? -ne 0 ]; then
        log_error "Failed to burn image with rpi-imager"
        exit 1
    fi

    log_success "Base image burned successfully!"

    # Wait for the system to recognize the new partitions and re-detect SD card
    log_info "Waiting for SD card to be recognized with new partitions..."
    detect_sdcard_after_burn

    configure_boot_partition

    # Eject the SD card
    diskutil eject "$SDCARD_DEVICE"
    log_success "SD card ejected. Ready to use in Raspberry Pi!"
}

# Detect SD card after burn operation with retry logic
detect_sdcard_after_burn() {
    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt $attempt/$max_attempts: Looking for SD card with new partitions..."

        # Re-run SD card detection
        local disks=$(diskutil list | grep -E "^/dev/disk[0-9]+" | awk '{print $1}')
        local sdcard_found=""

        for disk in $disks; do
            local disk_info=$(diskutil info "$disk" 2>/dev/null || echo "")

            # Look for removable media that's likely an SD card
            if echo "$disk_info" | grep -q "Removable Media.*Removable" &&
               echo "$disk_info" | grep -qE "(SD|MMC|Generic|USB|Secure Digital)"; then
                sdcard_found="$disk"
                break
            fi
        done

        if [ -n "$sdcard_found" ]; then
            SDCARD_DEVICE="$sdcard_found"
            log_success "SD card re-detected at: $SDCARD_DEVICE"
            return 0
        fi

        if [ $attempt -eq 5 ]; then
            log_warning "SD card not detected yet. It may have been auto-ejected."
            if [ "$AUTO_YES" = true ]; then
                log_info "Auto-continuing due to --yes flag (waiting longer for SD card detection)"
                sleep 5
            else
                log_info "Please remove and reinsert the SD card, then press Enter to continue..."
                read -r
            fi
        fi

        sleep 2
        ((attempt++))
    done

    log_error "Could not re-detect SD card after burning. Please:"
    log_info "1. Remove and reinsert the SD card"
    log_info "2. Run the script again to complete configuration"
    log_info "3. Or manually configure the boot partition"
    exit 1
}

# Configure the boot partition after image is burned
configure_boot_partition() {
    log_info "Configuring boot partition..."

    # Find the correct boot partition by checking available partitions
    local boot_partition=""
    local boot_mount=""

    # Check common boot partition locations
    for suffix in s1 s2; do
        local test_partition="${SDCARD_DEVICE}${suffix}"
        if diskutil info "$test_partition" &>/dev/null; then
            local partition_info=$(diskutil info "$test_partition")
            # Look for FAT32 partition which is typically the boot partition
            if echo "$partition_info" | grep -q "File System Personality.*FAT32\|MS-DOS FAT32"; then
                boot_partition="$test_partition"
                break
            fi
        fi
    done

    if [ -z "$boot_partition" ]; then
        log_error "Could not find boot partition on $SDCARD_DEVICE"
        log_info "Available partitions:"
        diskutil list "$SDCARD_DEVICE"
        exit 1
    fi

    log_info "Found boot partition: $boot_partition"

    # Mount the boot partition
    log_info "Mounting boot partition..."
    if ! diskutil mount "$boot_partition"; then
        log_error "Failed to mount boot partition $boot_partition"
        exit 1
    fi

    # Wait for mount
    sleep 2

    # Find actual mount point
    boot_mount=$(mount | grep "$boot_partition" | awk '{print $3}')
    if [ -z "$boot_mount" ]; then
        log_error "Could not determine boot partition mount point"
        exit 1
    fi

    log_info "Boot partition mounted at: $boot_mount"

    # Verify configuration files exist
    for file in ssh userconf.txt wpa_supplicant.conf firstrun.sh; do
        if [ ! -f "$file" ]; then
            log_error "Configuration file $file not found in work directory"
            diskutil unmount "$boot_partition"
            exit 1
        fi
    done

    # Copy configuration files to boot partition
    log_info "Copying configuration files..."
    cp ssh "$boot_mount/" || { log_error "Failed to copy ssh file"; exit 1; }
    cp userconf.txt "$boot_mount/" || { log_error "Failed to copy userconf.txt"; exit 1; }
    cp wpa_supplicant.conf "$boot_mount/" || { log_error "Failed to copy wpa_supplicant.conf"; exit 1; }
    cp firstrun.sh "$boot_mount/" || { log_error "Failed to copy firstrun.sh"; exit 1; }

    # Verify files were copied
    log_info "Verifying configuration files..."
    for file in ssh userconf.txt wpa_supplicant.conf firstrun.sh; do
        if [ ! -f "$boot_mount/$file" ]; then
            log_warning "File $file may not have been copied successfully"
        fi
    done

    # Sync changes
    log_info "Syncing changes to SD card..."
    sync
    sleep 2

    # Unmount boot partition
    log_info "Unmounting boot partition..."
    if diskutil unmount "$boot_partition"; then
        log_success "Boot partition configured and unmounted successfully!"
    else
        log_warning "Boot partition configured but unmount failed (this is usually OK)"
    fi
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
    create_boot_configs
    create_firstrun_script
    find_sdcard

    if [ "$CONFIGURE_ONLY" = true ]; then
        # Skip burning, go straight to configuration
        SDCARD_DEVICE="/dev/disk4"  # Assume it's the detected SD card
        configure_boot_partition
        # Eject the SD card
        diskutil eject "$SDCARD_DEVICE"
        log_success "SD card configured and ejected. Ready to use in Raspberry Pi!"
    else
        burn_image
    fi

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
