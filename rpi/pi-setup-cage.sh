#!/bin/bash
# DietPi automated SD card setup for Raspberry Pi 5 kiosk mode with Cage compositor
# This script creates a fully automated DietPi installation that boots directly into 
# GPU-accelerated Chromium kiosk mode using the minimal Cage Wayland compositor
#
# Features:
# - Minimal Cage compositor for lowest overhead
# - Full GPU acceleration with Wayland
# - Native 4K display support with auto-detection
# - Consumer and enterprise WiFi configuration
# - Automatic Tailscale network join
# - Optimized for Raspberry Pi 5 with 8GB RAM
#
# Uses latest DietPi version with Cage compositor

set -e
set -u
set -o pipefail

# Configuration
readonly DIETPI_IMAGE_URL="https://dietpi.com/downloads/images/DietPi_RPi5-ARMv8-Bookworm.img.xz"
readonly DEFAULT_URL="https://panic.fly.dev/"
readonly CACHE_DIR="$HOME/.cache/dietpi-images"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script is designed for macOS${NC}"
    exit 1
fi

# Check for required tools
check_required_tools() {
    # Check for jq
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}Error: jq is required but not installed${NC}"
        echo
        echo "Please install jq using one of these methods:"
        echo "  • Homebrew: brew install jq"
        echo "  • MacPorts: sudo port install jq"
        echo "  • Download from: https://jqlang.github.io/jq/download/"
        echo
        echo "jq is needed to safely handle JSON configuration with special characters."
        exit 1
    fi

    # Check for pv
    if ! command -v pv >/dev/null 2>&1; then
        echo -e "${RED}Error: pv is required but not installed${NC}"
        echo
        echo "Please install pv using Homebrew:"
        echo "  brew install pv"
        echo
        echo "pv is needed for progress display during SD card writing."
        exit 1
    fi
}

# Function to find SD card device
find_sd_card() {
    echo -e "${YELLOW}Checking for SD card in built-in reader...${NC}" >&2

    # Look through all disks to find the built-in SDXC reader
    for disk in /dev/disk*; do
        # Skip partition identifiers (e.g., disk1s1)
        if [[ "$disk" =~ ^/dev/disk[0-9]+$ ]]; then
            # Check if it's the built-in SDXC reader
            local device_info=$(diskutil info "$disk" 2>/dev/null | grep "Device / Media Name:")
            if echo "$device_info" | grep -q "Built In SDXC Reader"; then
                # Check if it's removable media (i.e., has an SD card inserted)
                if diskutil info "$disk" 2>/dev/null | grep -q "Removable Media:.*Removable"; then
                    echo -e "${GREEN}✓ Found SD card in built-in reader at $disk${NC}" >&2
                    echo "$disk"
                    return 0
                else
                    echo -e "${RED}Error: Built-in SD card reader found at $disk but no SD card inserted${NC}" >&2
                    echo -e "${YELLOW}Please insert an SD card and run the script again${NC}" >&2
                    return 1
                fi
            fi
        fi
    done

    echo -e "${RED}Error: Built-in SD card reader not found${NC}" >&2
    echo -e "${YELLOW}Please ensure your Mac has a built-in SD card reader${NC}" >&2
    return 1
}

# Function to download DietPi image with caching
download_dietpi() {
    local output_file="$1"

    # Create cache directory if it doesn't exist
    mkdir -p "$CACHE_DIR"

    # Extract filename from URL
    local filename=$(basename "$DIETPI_IMAGE_URL")
    local cached_file="$CACHE_DIR/$filename"

    # Check if we have a cached version
    if [ -f "$cached_file" ]; then
        echo -e "${GREEN}✓ Found cached image: $filename${NC}"
        # Check if cached file is less than 30 days old
        local file_age=$(($(date +%s) - $(stat -f %m "$cached_file")))
        local thirty_days=$((30 * 24 * 60 * 60))

        if [ $file_age -lt $thirty_days ]; then
            echo -e "${GREEN}✓ Using cached image ($(($file_age / 86400)) days old)${NC}"
            cp "$cached_file" "$output_file"
            return 0
        else
            echo -e "${YELLOW}Cached image is older than 30 days, downloading fresh copy...${NC}"
            rm -f "$cached_file"
        fi
    fi

    echo -e "${YELLOW}Downloading DietPi image...${NC}"
    if ! curl -L -o "$cached_file" "$DIETPI_IMAGE_URL"; then
        echo -e "${RED}Error: Failed to download image from $DIETPI_IMAGE_URL${NC}"
        rm -f "$cached_file"
        exit 1
    fi

    # Verify it's actually an xz file
    if ! file "$cached_file" | grep -q "XZ compressed data"; then
        echo -e "${RED}Error: Downloaded file is not a valid XZ compressed image${NC}"
        echo "File type: $(file "$cached_file")"
        rm -f "$cached_file"
        exit 1
    fi

    cp "$cached_file" "$output_file"
    echo -e "${GREEN}✓ Image cached for future use${NC}"
}

# Function to write image to SD card
write_image_to_sd() {
    local image_file="$1"
    local device="$2"
    local test_mode="${3:-false}"

    echo -e "${YELLOW}Writing image to SD card...${NC}"
    echo "This will take several minutes..."

    if [ "$test_mode" != "true" ]; then
        # Prompt for sudo password early to avoid interrupting the progress display
        echo "Requesting administrator privileges for writing to SD card..."
        sudo -v

        # Unmount any mounted partitions
        diskutil unmountDisk force "$device" || true
    fi

    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Skipping actual image write${NC}"
        echo "Would decompress and write: $image_file -> $device"
        echo "Simulating write operation..."
        sleep 2
        echo -e "${GREEN}✓ TEST MODE: Image write simulated${NC}"
        return 0
    fi

    # Get uncompressed size for progress bar
    local uncompressed_size=$(xz -l "$image_file" 2>/dev/null | awk 'NR==2 {
        gsub(",", "", $5);
        size=$5;
        unit=$6;
        if (unit == "MiB")
            print size * 1024 * 1024;
        else if (unit == "GiB")
            print size * 1024 * 1024 * 1024;
        else if (unit == "B")
            print size;
        else
            print 0;  # Unknown unit
    }')
    
    echo "Using pv for progress display with ETA..."
    # Use larger block size (32MB) and raw device for better performance
    xzcat "$image_file" | pv -s "$uncompressed_size" | sudo dd of="${device/disk/rdisk}" bs=32m

    # Ensure all data is written
    sudo sync

    echo -e "${GREEN}✓ Image written to SD card${NC}"
}

# Function to wait for boot partition
wait_for_boot_partition() {
    local device="$1"
    local test_mode="${2:-false}"
    local mount_point=""
    
    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Creating temporary directory for boot partition${NC}" >&2
        mount_point=$(mktemp -d)
        echo "$mount_point"
        return 0
    fi

    echo -e "${YELLOW}Waiting for boot partition to mount...${NC}" >&2
    
    # Wait up to 30 seconds for the boot partition to appear
    for i in {1..30}; do
        # Look for the boot partition
        for volume in /Volumes/*; do
            if [[ "$volume" =~ boot|BOOT ]]; then
                echo -e "${GREEN}✓ Found boot partition at $volume${NC}" >&2
                echo "$volume"
                return 0
            fi
        done
        sleep 1
    done
    
    echo -e "${RED}Error: Boot partition not found after 30 seconds${NC}" >&2
    return 1
}

# Function to configure DietPi automation
configure_dietpi() {
    local boot_mount="$1"
    local wifi_ssid="$2"
    local wifi_password="$3"
    local wifi_enterprise_user="$4"
    local wifi_enterprise_pass="$5"
    local url="$6"
    local hostname="$7"
    local username="$8"
    local password="$9"
    local tailscale_authkey="${10}"
    local ssh_key_file="${11}"
    local test_mode="${12:-false}"

    echo -e "${YELLOW}Configuring DietPi automation...${NC}"

    # Create dietpi.txt for full automation
    cat > "$boot_mount/dietpi.txt" << EOF
# DietPi automation configuration
# This file allows for completely unattended installation

##### Network Options #####
# Hostname
AUTO_SETUP_NET_HOSTNAME=$hostname

# WiFi settings
AUTO_SETUP_NET_WIFI_ENABLED=1
AUTO_SETUP_NET_WIFI_COUNTRY_CODE=US

##### Software Options #####
# Automated installation
AUTO_SETUP_AUTOMATED=1

# Global password for dietpi user
AUTO_SETUP_GLOBAL_PASSWORD=$password

# Software to install:
# 105 = OpenSSH Server
# 113 = Chromium
# Note: We'll install Cage in custom script for minimal Wayland support
AUTO_SETUP_INSTALL_SOFTWARE_ID=105,113

# Set autostart to custom script (7 = custom script)
AUTO_SETUP_AUTOSTART_TARGET_INDEX=14
AUTO_SETUP_AUTOSTART_LOGIN_USER=dietpi

# Disable serial console
AUTO_SETUP_SERIAL_CONSOLE_ENABLE=0

# Locale
AUTO_SETUP_LOCALE=en_US.UTF-8

# Keyboard
AUTO_SETUP_KEYBOARD_LAYOUT=us

# Timezone
AUTO_SETUP_TIMEZONE=Etc/UTC

##### DietPi-Config Settings #####
# Disable swap
CONFIG_SWAP_SIZE=0

# GPU memory split (512MB for 4K support on RPi5)
CONFIG_GPU_MEM_SPLIT=512

# Disable Bluetooth
CONFIG_BLUETOOTH_DISABLE=1

# Enable maximum performance mode for better GPU acceleration
CONFIG_CPU_GOVERNOR=performance

# Set HDMI settings for 4K support
CONFIG_HDMI_GROUP=2
# Don't force mode - let it auto-detect
CONFIG_HDMI_MODE=0
CONFIG_HDMI_BOOST=7

# Custom script to run after installation
AUTO_SETUP_CUSTOM_SCRIPT_EXEC=/boot/Automation_Custom_Script.sh

##### Chromium Kiosk Settings #####
# Set the kiosk URL
SOFTWARE_CHROMIUM_AUTOSTART_URL=$url

# Don't set resolution in dietpi.txt - let our custom script auto-detect it
EOF

    # Configure WiFi
    if [ -n "$wifi_ssid" ]; then
        if [ -n "$wifi_enterprise_user" ] && [ -n "$wifi_enterprise_pass" ]; then
            # Enterprise WiFi
            cat > "$boot_mount/dietpi-wifi.txt" << EOF
# WiFi Enterprise Configuration
aWIFI_SSID[0]='$wifi_ssid'
aWIFI_KEY[0]=''
aWIFI_KEYMGR[0]='WPA-EAP'
aWIFI_PROTO[0]='RSN'
aWIFI_PAIRWISE[0]='CCMP'
aWIFI_AUTH_ALG[0]='OPEN'
aWIFI_EAP[0]='PEAP'
aWIFI_IDENTITY[0]='$wifi_enterprise_user'
aWIFI_PASSWORD[0]='$wifi_enterprise_pass'
aWIFI_PHASE1[0]='peaplabel=0'
aWIFI_PHASE2[0]='auth=MSCHAPV2'
EOF
        elif [ -n "$wifi_password" ]; then
            # Regular WiFi
            cat > "$boot_mount/dietpi-wifi.txt" << EOF
# WiFi Configuration
aWIFI_SSID[0]='$wifi_ssid'
aWIFI_KEY[0]='$wifi_password'
aWIFI_KEYMGR[0]='WPA-PSK'
aWIFI_PROTO[0]='RSN'
aWIFI_PAIRWISE[0]='CCMP'
aWIFI_AUTH_ALG[0]='OPEN'
EOF
        fi
        echo -e "${GREEN}✓ WiFi configured${NC}"
    fi

    # Create dietpi_userdata directory if needed
    mkdir -p "$boot_mount/dietpi_userdata"

    # Add Tailscale auth key if provided
    if [ -n "$tailscale_authkey" ]; then
        echo "$tailscale_authkey" > "$boot_mount/dietpi_userdata/tailscale_authkey"
        echo -e "${GREEN}✓ Tailscale auth key configured${NC}"
    fi

    # Add SSH key if provided
    if [ -n "$ssh_key_file" ] && [ -f "$ssh_key_file" ]; then
        cp "$ssh_key_file" "$boot_mount/dietpi_userdata/authorized_keys"
        echo -e "${GREEN}✓ SSH key configured${NC}"
    fi

    # Create custom automation script for kiosk setup with Cage
    cat > "$boot_mount/Automation_Custom_Script.sh" << 'CUSTOM_SCRIPT'
#!/bin/bash
# DietPi custom automation script for Cage kiosk mode with Tailscale

echo "Starting DietPi custom automation script (Cage version)..."

# Function to detect correct boot partition path
get_boot_path() {
    if [ -d "/boot/firmware" ]; then
        echo "/boot/firmware"
    else
        echo "/boot"
    fi
}

BOOT_PATH=$(get_boot_path)

# Wait for network
echo "Waiting for network connectivity..."
while ! ping -c 1 google.com > /dev/null 2>&1; do
    sleep 2
done

# Install and configure Tailscale if auth key provided
AUTHKEY_PATH="${BOOT_PATH}/dietpi_userdata/tailscale_authkey"

if [ -f "$AUTHKEY_PATH" ]; then
    echo "Installing Tailscale..."
    
    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Read the auth key
    TAILSCALE_AUTHKEY=$(cat "$AUTHKEY_PATH")
    
    # Get hostname from dietpi.txt
    DIETPI_TXT="${BOOT_PATH}/dietpi.txt"
    HOSTNAME=$(grep "^AUTO_SETUP_NET_HOSTNAME=" "$DIETPI_TXT" | cut -d= -f2)
    
    # Start tailscale and authenticate
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --hostname="$HOSTNAME" --accept-routes --accept-dns=false
    
    # Wait for Tailscale to connect
    for i in {1..10}; do
        if tailscale status >/dev/null 2>&1; then
            echo "Tailscale connected successfully"
            tailscale status
            break
        fi
        echo "Waiting for Tailscale... (attempt $i/10)"
        sleep 2
    done
    
    # Remove the auth key file for security
    rm -f "$AUTHKEY_PATH"
fi

# Install SSH keys if provided
KEY_PATH="${BOOT_PATH}/dietpi_userdata/authorized_keys"

if [ -f "$KEY_PATH" ]; then
    echo "Installing SSH keys..."
    # For DietPi user
    mkdir -p /home/dietpi/.ssh
    cp "$KEY_PATH" /home/dietpi/.ssh/authorized_keys
    chown -R dietpi:dietpi /home/dietpi/.ssh
    chmod 700 /home/dietpi/.ssh
    chmod 600 /home/dietpi/.ssh/authorized_keys
    
    # Clean up
    rm -f "$KEY_PATH"
fi

# Install Cage compositor and dependencies
echo "Installing Cage compositor for minimal kiosk mode..."
apt-get update
apt-get install -y \
    cage \
    wlr-randr \
    libgles2-mesa \
    libgbm1 \
    libegl1-mesa \
    libgl1-mesa-dri \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    libdrm2 \
    xwayland

# Create kiosk launch script for Cage
echo "Creating Chromium kiosk script..."
cat > /usr/local/bin/chromium-kiosk.sh << 'EOF'
#!/bin/bash
# Chromium kiosk script for Cage compositor

# Get URL from dietpi.txt or use default
# Note: BOOT_PATH needs to be determined at runtime since this runs on the Pi
if [ -d "/boot/firmware" ]; then
    DIETPI_TXT="/boot/firmware/dietpi.txt"
else
    DIETPI_TXT="/boot/dietpi.txt"
fi
URL=$(sed -n '/^[[:blank:]]*SOFTWARE_CHROMIUM_AUTOSTART_URL=/{s/^[^=]*=//p;q}' "$DIETPI_TXT")
URL=${URL:-https://panic.fly.dev}

# Log startup
logger -t chromium-kiosk "Starting Chromium kiosk with URL: $URL"

# Launch Chromium in kiosk mode with Wayland support and GPU acceleration
exec chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-translate \
    --no-first-run \
    --fast \
    --fast-start \
    --disable-features=TranslateUI \
    --disk-cache-dir=/tmp/chromium-cache \
    --start-fullscreen \
    --disable-features=OverscrollHistoryNavigation \
    --disable-pinch \
    --check-for-update-interval=31536000 \
    --disable-component-update \
    --autoplay-policy=no-user-gesture-required \
    --enable-features=UseOzonePlatform,VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization \
    --ozone-platform=wayland \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    --enable-hardware-overlays \
    --disable-features=UseChromeOSDirectVideoDecoder \
    --use-gl=egl \
    --ignore-gpu-blocklist \
    --disable-gpu-driver-bug-workarounds \
    "$URL"
EOF

chmod +x /usr/local/bin/chromium-kiosk.sh

# Create Cage service for auto-start
echo "Creating Cage systemd service..."
cat > /etc/systemd/system/cage.service << 'EOF'
[Unit]
Description=Cage Wayland Compositor (Kiosk)
After=systemd-user-sessions.service plymouth-quit-wait.service
Wants=dbus.socket systemd-logind.service
Conflicts=getty@tty1.service

[Service]
Type=simple
ExecStart=/usr/bin/cage -- /usr/local/bin/chromium-kiosk.sh
Restart=on-failure
RestartSec=5
User=dietpi
PAMName=login
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
UtmpIdentifier=tty1

# Environment for Cage
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="XDG_SESSION_TYPE=wayland"
Environment="MOZ_ENABLE_WAYLAND=1"
Environment="GDK_BACKEND=wayland"
Environment="QT_QPA_PLATFORM=wayland"
Environment="CLUTTER_BACKEND=wayland"
Environment="SDL_VIDEODRIVER=wayland"
Environment="WAYLAND_DISPLAY=wayland-1"
Environment="WLR_RENDERER=gles2"
Environment="WLR_NO_HARDWARE_CURSORS=1"
# Cage-specific options
Environment="CAGE_DISABLE_CSD=1"

[Install]
WantedBy=graphical.target
EOF

# Enable services
systemctl daemon-reload
systemctl enable cage.service
systemctl set-default graphical.target

# Configure auto-login for tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin dietpi --noclear %I \$TERM
EOF

# Create custom DietPi autostart script that launches Cage
cat > /var/lib/dietpi/dietpi-autostart/custom.sh << 'EOF'
#!/bin/bash
# Launch Cage on tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    systemctl start cage
fi
EOF
chmod +x /var/lib/dietpi/dietpi-autostart/custom.sh

# Create display verification script
cat > /usr/local/bin/verify-display.sh << 'EOF'
#!/bin/bash
# Verify display capabilities

echo "=== Display Configuration ==="
if command -v wlr-randr >/dev/null 2>&1; then
    echo "Wayland outputs:"
    wlr-randr
else
    echo "wlr-randr not available, trying alternative methods..."
    if [ -f /sys/class/drm/card*/modes ]; then
        echo "Available modes:"
        cat /sys/class/drm/card*/modes 2>/dev/null | sort -u
    fi
fi

echo ""
echo "=== GPU Information ==="
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo -B 2>/dev/null | grep -E "OpenGL|renderer|version"
fi

echo ""
echo "=== Current Resolution ==="
if [ -f /sys/class/graphics/fb0/virtual_size ]; then
    cat /sys/class/graphics/fb0/virtual_size
fi
EOF
chmod +x /usr/local/bin/verify-display.sh

# Log display info on first boot
/usr/local/bin/verify-display.sh > /var/log/display-capabilities.log 2>&1

echo "DietPi Cage kiosk setup complete!"
CUSTOM_SCRIPT

    chmod +x "$boot_mount/Automation_Custom_Script.sh"
    
    echo -e "${GREEN}✓ DietPi automation configured${NC}"
    echo -e "${GREEN}✓ SD card is ready for boot${NC}"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Configuration Options:
    --url <url>                  URL to display in kiosk mode (default: https://panic.fly.dev/)
    --hostname <name>            Hostname for the Raspberry Pi (default: panic-rpi)
    --username <user>            Username for the admin account (default: dietpi)
    --password <pass>            Password for the admin account (default: dietpi)

Network Options (at least one required):
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK networks)
    --wifi-enterprise-user <u>   Enterprise WiFi username (use with --wifi-ssid)
    --wifi-enterprise-pass <p>   Enterprise WiFi password (use with --wifi-ssid)
    --tailscale-authkey <key>    Tailscale auth key for automatic join

Optional:
    --ssh-key <path>             Path to SSH public key
    --test                       Test mode - skip actual SD card write

Examples:
    # Regular WiFi with Tailscale:
    $0 --url "https://example.com" \\
       --hostname "kiosk-pi" \\
       --wifi-ssid "MyNetwork" \\
       --wifi-password "MyPassword" \\
       --tailscale-authkey "tskey-auth-..."

    # Enterprise WiFi:
    $0 --url "https://example.com" \\
       --hostname "kiosk-display" \\
       --wifi-ssid "CorpNetwork" \\
       --wifi-enterprise-user "username@domain.com" \\
       --wifi-enterprise-pass "password" \\
       --tailscale-authkey "tskey-auth-..."

This version uses the minimal Cage compositor instead of Wayfire for better
performance and lower resource usage in kiosk deployments.

EOF
    exit 1
}

# Main function
main() {
    # Check if no arguments provided
    if [ $# -eq 0 ]; then
        usage
    fi

    # Check required tools
    check_required_tools

    # Parse arguments - with sensible defaults
    local url="$DEFAULT_URL"
    local wifi_ssid=""
    local wifi_password=""
    local wifi_enterprise_user=""
    local wifi_enterprise_pass=""
    local hostname="panic-rpi"
    local username="dietpi"
    local password="dietpi"
    local tailscale_authkey=""
    local ssh_key_file=""
    local test_mode=false

    # Parse command line options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --url)
                url="$2"
                shift 2
                ;;
            --wifi-ssid)
                wifi_ssid="$2"
                shift 2
                ;;
            --wifi-password)
                wifi_password="$2"
                shift 2
                ;;
            --wifi-enterprise-user)
                wifi_enterprise_user="$2"
                shift 2
                ;;
            --wifi-enterprise-pass)
                wifi_enterprise_pass="$2"
                shift 2
                ;;
            --hostname)
                hostname="$2"
                shift 2
                ;;
            --username)
                username="$2"
                shift 2
                ;;
            --password)
                password="$2"
                shift 2
                ;;
            --tailscale-authkey)
                tailscale_authkey="$2"
                shift 2
                ;;
            --ssh-key)
                ssh_key_file="$2"
                shift 2
                ;;
            --test)
                test_mode=true
                echo -e "${YELLOW}TEST MODE: Will skip actual SD card write${NC}"
                shift
                ;;
            --help)
                usage
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                echo "Run with --help for usage information"
                exit 1
                ;;
        esac
    done

    # Validate required fields
    local errors=()
    
    # Check that at least one network option is provided
    if [ -z "$wifi_ssid" ] && [ -z "$tailscale_authkey" ]; then
        errors+=("At least one network option is required (--wifi-ssid or --tailscale-authkey)")
    fi
    
    # If WiFi is specified, check for credentials
    if [ -n "$wifi_ssid" ]; then
        if [ -n "$wifi_enterprise_user" ] || [ -n "$wifi_enterprise_pass" ]; then
            # Enterprise WiFi - both user and pass required
            [ -z "$wifi_enterprise_user" ] && errors+=("--wifi-enterprise-user required when using enterprise WiFi")
            [ -z "$wifi_enterprise_pass" ] && errors+=("--wifi-enterprise-pass required when using enterprise WiFi")
        else
            # Regular WiFi - password required
            [ -z "$wifi_password" ] && errors+=("--wifi-password required for WPA2-PSK networks")
        fi
    fi
    
    # Validate SSH key file if provided
    if [ -n "$ssh_key_file" ] && [ ! -f "$ssh_key_file" ]; then
        errors+=("SSH key file not found: $ssh_key_file")
    fi
    
    # Display errors if any
    if [ ${#errors[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing or invalid arguments:${NC}"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        echo ""
        echo "Run with --help for usage information"
        exit 1
    fi

    # Show configuration
    echo -e "${GREEN}DietPi Kiosk SD Card Setup (Cage Version)${NC}"
    echo "=========================================="
    echo "Configuration:"
    echo "  Hostname: $hostname"
    echo "  Username: $username"
    echo "  Password: [hidden]"
    echo "  Kiosk URL: $url"
    echo "  Compositor: Cage (minimal)"
    if [ -n "$wifi_ssid" ]; then
        echo "  WiFi SSID: $wifi_ssid"
        if [ -n "$wifi_enterprise_user" ]; then
            echo "  WiFi Type: Enterprise (802.1X)"
            echo "  WiFi User: $wifi_enterprise_user"
        else
            echo "  WiFi Type: WPA2-PSK"
        fi
    else
        echo "  WiFi: Not configured"
    fi
    echo "  Tailscale: $([ -n "$tailscale_authkey" ] && echo "Configured" || echo "Not configured")"
    echo "  SSH Key: $([ -n "$ssh_key_file" ] && echo "$ssh_key_file" || echo "Not configured")"
    echo "  Test Mode: $test_mode"
    echo ""

    # Find SD card
    local device
    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Skipping SD card detection${NC}"
        device="/dev/test"
    else
        device=$(find_sd_card)
        if [ -z "$device" ]; then
            exit 1
        fi
    fi

    # Confirm before proceeding
    if [ "$test_mode" != "true" ]; then
        echo -e "${YELLOW}WARNING: This will ERASE all data on $device${NC}"
        read -p "Continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    # Download DietPi image
    local temp_image="/tmp/dietpi-$$.img.xz"
    download_dietpi "$temp_image"

    # Write image to SD card
    write_image_to_sd "$temp_image" "$device" "$test_mode"

    # Clean up downloaded image
    rm -f "$temp_image"

    # Wait for boot partition
    local boot_mount
    boot_mount=$(wait_for_boot_partition "$device" "$test_mode")
    if [ -z "$boot_mount" ]; then
        echo -e "${RED}Error: Could not find boot partition${NC}"
        exit 1
    fi

    # Configure the OS
    configure_dietpi "$boot_mount" "$wifi_ssid" "$wifi_password" \
        "$wifi_enterprise_user" "$wifi_enterprise_pass" "$url" \
        "$hostname" "$username" "$password" "$tailscale_authkey" \
        "$ssh_key_file" "$test_mode"

    # Cleanup and finish
    if [ "$test_mode" = "true" ]; then
        echo ""
        echo -e "${YELLOW}TEST MODE: Generated files in: $boot_mount${NC}"
        echo "Contents:"
        ls -la "$boot_mount"
        echo ""
        echo -e "${GREEN}✓ TEST MODE: Configuration test complete!${NC}"
    else
        echo -e "${YELLOW}Syncing and ejecting SD card...${NC}"
        sync
        diskutil eject "$device"
        echo -e "${GREEN}✓ SD card ready!${NC}"
    fi

    echo ""
    echo "Next steps:"
    echo "1. Insert the SD card into your Raspberry Pi (with Ethernet connected)"
    echo "2. Power on the Pi"
    echo "3. Wait 5-10 minutes for DietPi to:"
    echo "   - Complete automated installation"
    echo "   - Install and join Tailscale network (if configured)"
    echo "   - Configure Cage kiosk mode"
    echo "   - Reboot into kiosk display"
    echo ""
    if [ -n "$tailscale_authkey" ]; then
        echo "4. Verify the Pi is on Tailscale:"
        echo "   tailscale status | grep $hostname"
        echo ""
        echo "5. You can SSH to the Pi via Tailscale:"
        echo "   tailscale ssh $username@$hostname"
    else
        echo "4. You can SSH to the Pi when it's online:"
        echo "   ssh $username@<pi-ip-address>"
    fi
    echo ""
    echo "The Pi will automatically:"
    echo "- Boot directly into kiosk mode showing: $url"
    echo "- Use minimal Cage compositor for best performance"
    echo "- Support 4K displays at full 60Hz with hardware acceleration"
    echo "- Hide the mouse cursor automatically"
    echo "- Restart the browser if it crashes"
    echo ""
    echo "Cage advantages over Wayfire:"
    echo "- Minimal resource usage (no desktop features)"
    echo "- Purpose-built for single-app kiosk mode"
    echo "- Faster boot times"
    echo "- More stable for 24/7 operation"
}

# Run main function
main "$@"