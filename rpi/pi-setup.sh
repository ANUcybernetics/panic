#!/bin/bash
# DietPi automated SD card setup for Raspberry Pi 5 kiosk mode with Wayland
# This script creates a fully automated DietPi installation that boots directly into 
# GPU-accelerated Chromium kiosk mode using Cage compositor and automatically joins Tailscale
#
# Features:
# - Full GPU acceleration with minimal Cage Wayland compositor
# - Native 4K display support with auto-detection
# - Consumer and enterprise WiFi configuration
# - Automatic Tailscale network join
# - Optimized for Raspberry Pi 5 with 8GB RAM
#
# Uses latest DietPi version

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
        echo -e "${GREEN}✓ Using cached image: $filename${NC}"
        cp "$cached_file" "$output_file"
        return 0
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

    echo "Using pv for progress display..."
    # Use larger block size (32MB) and raw device for better performance
    # Let pv figure out the size automatically from the pipe
    xzcat "$image_file" | pv | sudo dd of="${device/disk/rdisk}" bs=32m

    # Ensure all data is written
    sudo sync

    echo -e "${GREEN}✓ Image written to SD card${NC}"
    
    # Force macOS to mount the disk
    echo -e "${YELLOW}Mounting disk partitions...${NC}"
    diskutil mountDisk "$device" || true
    
    # Give macOS a moment to mount the partitions
    sleep 3
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
    
    # Wait up to 45 seconds for the boot partition to appear
    for i in {1..45}; do
        # Look for any new volume that might be the boot partition
        # DietPi might name it differently - check for common patterns
        for volume in /Volumes/*; do
            # Skip known system volumes
            if [[ "$volume" == "/Volumes/Macintosh HD" ]] || [[ "$volume" == "/Volumes/Macintosh HD - Data" ]]; then
                continue
            fi
            
            # Check if it's likely a boot partition
            local volume_name=$(basename "$volume")
            # Use tr for lowercase conversion (more compatible)
            local volume_lower=$(echo "$volume_name" | tr '[:upper:]' '[:lower:]')
            
            if [[ "$volume_lower" =~ boot ]] || [[ "$volume_lower" =~ dietpi ]] || [[ "$volume_name" == "NO NAME" ]] || [[ "$volume_name" =~ ^[A-Z0-9_]+$ ]]; then
                # Verify it's the SD card by checking for expected files
                if [ -d "$volume" ] && [ -r "$volume" ]; then
                    echo -e "${GREEN}✓ Found boot partition${NC}" >&2
                    echo "$volume"
                    return 0
                fi
            fi
        done
        
        # Show progress every 10 seconds
        if [ $((i % 10)) -eq 0 ]; then
            echo -e "${YELLOW}Still waiting... ($i/45)${NC}" >&2
        fi
        
        sleep 1
    done
    
    echo -e "${RED}Error: Boot partition not found after 45 seconds${NC}" >&2
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

# Ethernet settings - ensure ethernet is enabled
AUTO_SETUP_NET_ETHERNET_ENABLED=1

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
# Note: We'll install Wayfire in custom script for Wayland support
AUTO_SETUP_INSTALL_SOFTWARE_ID=105,113

# Set autostart to disabled - we'll use systemd services instead
AUTO_SETUP_AUTOSTART_TARGET_INDEX=0

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

# HDMI settings for 4K support with auto-detection
CONFIG_HDMI_GROUP=0
# Mode 0 = auto-detect native resolution
CONFIG_HDMI_MODE=0
# Boost signal for 4K displays
CONFIG_HDMI_BOOST=7

# Enable HDMI audio
CONFIG_HDMI_FORCE_HOTPLUG=1
CONFIG_HDMI_DRIVE=2

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

    # Add SSH key if provided and exists
    if [ -f "$ssh_key_file" ]; then
        cp "$ssh_key_file" "$boot_mount/dietpi_userdata/authorized_keys"
        echo -e "${GREEN}✓ SSH key configured${NC}"
    elif [ -n "$ssh_key_file" ]; then
        echo -e "${YELLOW}⚠ SSH key file not found: $ssh_key_file${NC}"
    fi

    # Create custom automation script for kiosk setup
    cat > "$boot_mount/Automation_Custom_Script.sh" << 'CUSTOM_SCRIPT'
#!/bin/bash
# DietPi custom automation script for kiosk mode with Tailscale

echo "Starting DietPi custom automation script..."

# Function to detect correct boot partition path
get_boot_path() {
    if [ -d "/boot/firmware" ]; then
        echo "/boot/firmware"
    else
        echo "/boot"
    fi
}

BOOT_PATH=$(get_boot_path)

# Enable systemd network waiting service
systemctl enable systemd-networkd-wait-online.service

# Create Tailscale setup script
cat > /usr/local/bin/setup-tailscale.sh << 'EOF'
#!/bin/bash
# Tailscale setup script

BOOT_PATH=$([ -d "/boot/firmware" ] && echo "/boot/firmware" || echo "/boot")
AUTHKEY_PATH="${BOOT_PATH}/dietpi_userdata/tailscale_authkey"

if [ -f "$AUTHKEY_PATH" ]; then
    echo "Setting up Tailscale..."
    
    # Install Tailscale if not already installed
    if ! command -v tailscale >/dev/null 2>&1; then
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    
    # Read the auth key
    TAILSCALE_AUTHKEY=$(cat "$AUTHKEY_PATH")
    
    # Get hostname from dietpi.txt
    DIETPI_TXT="${BOOT_PATH}/dietpi.txt"
    HOSTNAME=$(grep "^AUTO_SETUP_NET_HOSTNAME=" "$DIETPI_TXT" | cut -d= -f2)
    
    # Start tailscale and authenticate
    echo "Starting Tailscale with hostname: $HOSTNAME"
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
else
    echo "No Tailscale auth key found, skipping setup"
fi
EOF
chmod +x /usr/local/bin/setup-tailscale.sh

# Create Tailscale systemd service
cat > /etc/systemd/system/tailscale-setup.service << 'EOF'
[Unit]
Description=Tailscale Initial Setup
After=network-online.target tailscaled.service
Wants=network-online.target
Before=cage-kiosk.service
ConditionPathExists=/usr/local/bin/setup-tailscale.sh

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/setup-tailscale.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

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

# Install Cage compositor and dependencies for minimal kiosk mode
echo "Installing Cage compositor and dependencies..."
apt-get update
apt-get install -y \
    cage \
    seatd \
    wlr-randr \
    libgles2-mesa \
    libgbm1 \
    libegl1-mesa \
    libgl1-mesa-dri \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    libdrm2 \
    xwayland \
    pulseaudio \
    pulseaudio-utils

# Add dietpi user to necessary groups for GPU, TTY, and audio access
usermod -a -G video,render,input,tty,audio dietpi

# Configure PulseAudio for HDMI output
echo "Configuring audio for HDMI output..."
cat > /etc/pulse/default.pa.d/hdmi-audio.pa << 'EOF'
# Set HDMI as default audio output
load-module module-alsa-sink device=hdmi:CARD=vc4hdmi0,DEV=0 sink_name=hdmi0 sink_properties="device.description='HDMI-1'"
load-module module-alsa-sink device=hdmi:CARD=vc4hdmi1,DEV=0 sink_name=hdmi1 sink_properties="device.description='HDMI-2'"

# Set the first available HDMI as default
set-default-sink hdmi0
EOF

# Create a script to ensure audio works after boot
cat > /usr/local/bin/setup-hdmi-audio.sh << 'EOF'
#!/bin/bash
# Wait for PulseAudio to start
sleep 5

# Find active HDMI output and set as default
for card in /proc/asound/card*; do
    if grep -q "vc4-hdmi" "$card/id" 2>/dev/null; then
        card_num=$(basename "$card" | sed 's/card//')
        # Check if HDMI is connected
        if grep -q "connected" "/sys/class/drm/card$card_num-HDMI-A-1/status" 2>/dev/null || \
           grep -q "connected" "/sys/class/drm/card$card_num-HDMI-A-2/status" 2>/dev/null; then
            pactl set-default-sink "hdmi$card_num" 2>/dev/null || true
            echo "Set HDMI audio output to card $card_num"
            break
        fi
    fi
done

# Unmute and set volume
amixer set Master unmute 2>/dev/null || true
amixer set Master 80% 2>/dev/null || true
EOF
chmod +x /usr/local/bin/setup-hdmi-audio.sh

# Create systemd service to run audio setup after cage starts
cat > /etc/systemd/system/hdmi-audio-setup.service << 'EOF'
[Unit]
Description=Configure HDMI Audio Output
After=cage-kiosk.service sound.target
Wants=sound.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-hdmi-audio.sh
User=dietpi
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable hdmi-audio-setup.service

# Create kiosk launch script for Wayland
echo "Creating Chromium kiosk script..."
cat > /usr/local/bin/chromium-kiosk.sh << 'EOF'
#!/bin/bash
# Chromium kiosk script for Wayland

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

# Hide mouse cursor - Wayland doesn't need unclutter
export XCURSOR_THEME=DMZ-White
export XCURSOR_SIZE=1

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

# Create Cage service for kiosk mode
echo "Creating Cage systemd service..."
cat > /etc/systemd/system/cage-kiosk.service << 'EOF'
[Unit]
Description=Cage Wayland Kiosk
After=multi-user.target network-online.target systemd-user-sessions.service
Wants=network-online.target

[Service]
Type=simple
User=dietpi
Group=dietpi
PAMName=login

# Runtime directory
RuntimeDirectory=cage
RuntimeDirectoryMode=0700

# Environment
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="XDG_SESSION_TYPE=wayland"
Environment="WLR_BACKEND=drm"
# Allow both HDMI outputs to be detected - card1 handles display output on RPi5
Environment="WLR_DRM_DEVICES=/dev/dri/card1"
Environment="WLR_RENDERER=gles2"
Environment="WLR_NO_HARDWARE_CURSORS=1"

# Chromium environment for Wayland
Environment="MOZ_ENABLE_WAYLAND=1"
Environment="GDK_BACKEND=wayland"
Environment="QT_QPA_PLATFORM=wayland"

# Audio configuration for HDMI output
Environment="PULSE_RUNTIME_PATH=/run/user/1000/pulse"

# Wait for GPU and ensure audio is initialized
ExecStartPre=/bin/bash -c 'until [ -e /dev/dri/card0 ]; do echo "Waiting for GPU..."; sleep 1; done'
ExecStartPre=/bin/bash -c 'if [ -e /proc/asound/cards ]; then echo "Audio system ready"; fi'

# Start cage with chromium
# Note: Cage will auto-detect the connected display and use native resolution
ExecStart=/usr/bin/cage -- /usr/local/bin/chromium-kiosk.sh

# Restart policy
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
EOF

# Disable getty on tty1 to avoid conflicts
systemctl disable getty@tty1.service

# Enable services
systemctl daemon-reload
systemctl enable cage-kiosk.service
systemctl enable tailscale-setup.service
systemctl set-default graphical.target

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

# Create a health check timer for the kiosk
cat > /etc/systemd/system/kiosk-health-check.service << 'EOF'
[Unit]
Description=Kiosk Health Check
After=cage-kiosk.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kiosk-health-check.sh
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/kiosk-health-check.timer << 'EOF'
[Unit]
Description=Run Kiosk Health Check every 5 minutes
Requires=kiosk-health-check.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

cat > /usr/local/bin/kiosk-health-check.sh << 'EOF'
#!/bin/bash
# Simple health check for kiosk mode

# Check if Cage is running
if ! pgrep -x cage > /dev/null; then
    echo "Cage not running, attempting restart..."
    systemctl restart cage-kiosk.service
fi

# Check if Chromium is running
if ! pgrep -f "chromium.*--kiosk" > /dev/null; then
    echo "Chromium not running in kiosk mode"
    # Cage should restart it automatically
fi

# Log current status
echo "Kiosk health check completed at $(date)"
EOF
chmod +x /usr/local/bin/kiosk-health-check.sh

# Enable the health check timer
systemctl enable kiosk-health-check.timer

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

Network Options (optional):
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK networks)
    --wifi-enterprise-user <u>   Enterprise WiFi username (use with --wifi-ssid)
    --wifi-enterprise-pass <p>   Enterprise WiFi password (use with --wifi-ssid)
    --tailscale-authkey <key>    Tailscale auth key for automatic join

Optional:
    --ssh-key <path>             Path to SSH public key (default: ~/.ssh/panic_rpi_ssh.pub)
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
    local ssh_key_file="$HOME/.ssh/panic_rpi_ssh.pub"
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
    
    # If WiFi is specified, check for credentials
    if [ -n "$wifi_ssid" ]; then
        # Check for problematic characters in WiFi credentials
        if [[ "$wifi_ssid" =~ [\'\"] ]]; then
            errors+=("WiFi SSID cannot contain quotes (single or double)")
        fi
        
        if [ -n "$wifi_enterprise_user" ] || [ -n "$wifi_enterprise_pass" ]; then
            # Enterprise WiFi - both user and pass required
            [ -z "$wifi_enterprise_user" ] && errors+=("--wifi-enterprise-user required when using enterprise WiFi")
            [ -z "$wifi_enterprise_pass" ] && errors+=("--wifi-enterprise-pass required when using enterprise WiFi")
            
            # Check for quotes in enterprise credentials
            if [[ "$wifi_enterprise_user" =~ [\'\"] ]]; then
                errors+=("WiFi enterprise username cannot contain quotes")
            fi
            if [[ "$wifi_enterprise_pass" =~ [\'\"] ]]; then
                errors+=("WiFi enterprise password cannot contain quotes")
            fi
        else
            # Regular WiFi - password required
            [ -z "$wifi_password" ] && errors+=("--wifi-password required for WPA2-PSK networks")
            
            # Check for quotes in password
            if [[ "$wifi_password" =~ [\'\"] ]]; then
                errors+=("WiFi password cannot contain quotes")
            fi
        fi
    fi
    
    # Validate SSH key file if provided (note: we always have a default now)
    if [ -n "$ssh_key_file" ] && [ "$ssh_key_file" != "$HOME/.ssh/panic_rpi_ssh.pub" ] && [ ! -f "$ssh_key_file" ]; then
        errors+=("SSH key file not found: $ssh_key_file")
    fi
    
    # Validate URL format
    if ! [[ "$url" =~ ^https?:// ]]; then
        errors+=("Invalid URL format: $url (must start with http:// or https://)")
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
    echo -e "${GREEN}DietPi Kiosk SD Card Setup${NC}"
    echo "============================="
    echo "Configuration:"
    echo "  Hostname: $hostname"
    echo "  Username: $username"
    echo "  Password: [hidden]"
    echo "  Kiosk URL: $url"
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
    echo "  SSH Key: $([ -f "$ssh_key_file" ] && echo "$ssh_key_file" || echo "Not configured")"
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
        # Eject the entire SD card device (this will unmount all partitions)
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
    echo "   - Configure kiosk mode"
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
    echo "- Use minimal Cage compositor with GPU acceleration"
    echo "- Support 4K displays at full 60Hz with hardware acceleration"
    echo "- Hide the mouse cursor"
    echo "- Restart the browser if it crashes"
    echo ""
    echo "Cage advantages:"
    echo "- Minimal resource usage (no desktop features)"
    echo "- Purpose-built for single-app kiosk mode"
    echo "- Better stability for 24/7 operation"
}

# Run main function
main "$@"
