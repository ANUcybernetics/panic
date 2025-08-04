#!/bin/bash
# Raspberry Pi OS Bookworm automated SD card setup for Raspberry Pi 5 kiosk mode
# This script creates a fully automated Raspberry Pi OS installation that boots directly into 
# GPU-accelerated Chromium kiosk mode using Wayland/Wayfire and automatically joins Tailscale
#
# Features:
# - Full GPU acceleration with Wayfire Wayland compositor
# - Native 4K display support with auto-detection
# - Consumer and enterprise WiFi configuration
# - Automatic Tailscale network join
# - Optimized for Raspberry Pi 5 with 8GB RAM
# - Uses official Raspberry Pi OS Bookworm
#
# Uses latest Raspberry Pi OS Bookworm (64-bit)

set -e
set -u
set -o pipefail

# Configuration
readonly RASPIOS_IMAGE_URL="https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64.img.xz"
readonly DEFAULT_URL="https://panic.fly.dev/"
readonly CACHE_DIR="$HOME/.cache/raspios-images"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Check if running on Linux (Ubuntu)
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}Error: This script is designed for Linux (Ubuntu)${NC}"
    echo "The macOS version is being deprecated due to OS compatibility issues."
    exit 1
fi

# Check for required tools
check_required_tools() {
    local missing_tools=()
    
    # Check for required commands
    for cmd in curl xz pv dd mktemp jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_tools+=("$cmd")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
        echo
        echo "Please install missing tools using:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install ${missing_tools[*]}"
        exit 1
    fi
}

# Function to find SD card device
find_sd_card() {
    echo -e "${YELLOW}Looking for SD card devices...${NC}" >&2
    
    # List removable block devices and USB card readers
    local devices=()
    local device_info=()
    
    while IFS= read -r line; do
        local device="/dev/$line"
        local removable=$(cat "/sys/block/$line/removable" 2>/dev/null || echo "0")
        local size=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1 || echo "0")
        local size_gb=$((size / 1024 / 1024 / 1024))
        
        # Get vendor and model info
        local vendor=$(cat "/sys/block/$line/device/vendor" 2>/dev/null | tr -d ' ' || echo "")
        local model=$(cat "/sys/block/$line/device/model" 2>/dev/null | tr -d ' ' || echo "Unknown")
        
        # Check for USB card readers (often show as Multi-Reader or similar)
        local is_card_reader=0
        if [[ "$model" =~ Multi-Reader ]] || [[ "$model" =~ Card-Reader ]] || [[ "$model" =~ SD.*Reader ]]; then
            is_card_reader=1
        fi
        
        # Include device if:
        # 1. It's removable with valid size, OR
        # 2. It's a card reader slot with valid size (card readers show multiple slots, only count ones with cards)
        if ([ "$removable" = "1" ] || [ "$is_card_reader" = "1" ]) && [ "$size_gb" -ge 2 ] && [ "$size_gb" -le 256 ]; then
            devices+=("$device")
            device_info+=("${size_gb}GB - $vendor $model")
        fi
    done < <(ls /sys/block/ | grep -E '^(sd|mmcblk)[a-z0-9]*$')
    
    if [ ${#devices[@]} -eq 0 ]; then
        echo -e "${RED}Error: No SD card devices found${NC}" >&2
        echo -e "${YELLOW}Please insert an SD card and run the script again${NC}" >&2
        echo -e "${YELLOW}Note: USB card readers should show up when a card is inserted${NC}" >&2
        return 1
    fi
    
    if [ ${#devices[@]} -eq 1 ]; then
        echo -e "${GREEN}✓ Found SD card at ${devices[0]} (${device_info[0]})${NC}" >&2
        echo "${devices[0]}"
        return 0
    fi
    
    # Multiple devices found, ask user to select
    echo -e "${YELLOW}Multiple removable devices found:${NC}" >&2
    for i in "${!devices[@]}"; do
        local dev="${devices[$i]}"
        local info="${device_info[$i]}"
        echo "  $((i+1))) $dev - $info" >&2
    done
    
    echo -n "Select device (1-${#devices[@]}): " >&2
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#devices[@]} ]; then
        local selected="${devices[$((selection-1))]}"
        local selected_info="${device_info[$((selection-1))]}"
        echo -e "${GREEN}✓ Selected $selected ($selected_info)${NC}" >&2
        echo "$selected"
        return 0
    else
        echo -e "${RED}Error: Invalid selection${NC}" >&2
        return 1
    fi
}

# Function to download Raspberry Pi OS image with caching
download_raspios() {
    local output_file="$1"

    # Create cache directory if it doesn't exist
    mkdir -p "$CACHE_DIR"

    # Extract filename from URL
    local filename=$(basename "$RASPIOS_IMAGE_URL")
    local cached_file="$CACHE_DIR/$filename"

    # Check if we have a cached version
    if [ -f "$cached_file" ]; then
        echo -e "${GREEN}✓ Using cached image: $filename${NC}"
        cp "$cached_file" "$output_file"
        return 0
    fi

    echo -e "${YELLOW}Downloading Raspberry Pi OS image...${NC}"
    if ! curl -L -o "$cached_file" "$RASPIOS_IMAGE_URL"; then
        echo -e "${RED}Error: Failed to download image from $RASPIOS_IMAGE_URL${NC}"
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

    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Skipping actual image write${NC}"
        echo "Would decompress and write: $image_file -> $device"
        echo "Simulating write operation..."
        sleep 2
        echo -e "${GREEN}✓ TEST MODE: Image write simulated${NC}"
        return 0
    fi

    # Unmount any mounted partitions
    for part in "${device}"*; do
        if mountpoint -q "$part" 2>/dev/null; then
            sudo umount "$part" || true
        fi
    done

    # Get uncompressed size for progress display
    local uncompressed_size=$(xz -l "$image_file" 2>/dev/null | grep -E "^ *[0-9]" | awk '{print $5}' | sed 's/,//g')
    
    if [ -n "$uncompressed_size" ] && [ "$uncompressed_size" != "0" ]; then
        echo "Uncompressed image size: $((uncompressed_size / 1024 / 1024 / 1024)) GB"
        echo "Using pv for progress display with accurate ETA..."
        # Use larger block size (32MB) for better performance
        xzcat "$image_file" | pv -s "$uncompressed_size" | sudo dd of="$device" bs=32M status=none
    else
        echo "Using pv for progress display (size unknown)..."
        # Fall back to size-less progress display
        xzcat "$image_file" | pv | sudo dd of="$device" bs=32M status=none
    fi

    # Ensure all data is written
    sudo sync

    echo -e "${GREEN}✓ Image written to SD card${NC}"
    
    # Force kernel to re-read partition table
    sudo partprobe "$device" || true
    sleep 2
}

# Function to wait for boot partition
wait_for_boot_partition() {
    local device="$1"
    local test_mode="${2:-false}"
    
    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Creating temporary directory for boot partition${NC}" >&2
        local mount_point=$(mktemp -d)
        echo "$mount_point"
        return 0
    fi

    echo -e "${YELLOW}Waiting for boot partition to mount...${NC}" >&2
    
    # Create temporary mount point
    local mount_point=$(mktemp -d)
    
    # Try to mount the boot partition
    # For Raspberry Pi OS, it's usually the first partition
    local boot_device="${device}1"
    if [[ "$device" =~ mmcblk ]]; then
        boot_device="${device}p1"
    fi
    
    # Mount the boot partition
    if sudo mount "$boot_device" "$mount_point" 2>/dev/null; then
        echo -e "${GREEN}✓ Mounted boot partition at $mount_point${NC}" >&2
        echo "$mount_point"
        return 0
    else
        echo -e "${RED}Error: Failed to mount boot partition${NC}" >&2
        rmdir "$mount_point"
        return 1
    fi
}

# Function to configure Raspberry Pi OS
configure_raspios() {
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

    echo -e "${YELLOW}Configuring Raspberry Pi OS for automated setup...${NC}"

    # Helper function to write files (uses sudo in real mode, regular write in test mode)
    write_file() {
        local file="$1"
        local content="$2"
        if [ "$test_mode" = "true" ]; then
            echo "$content" > "$file"
        else
            echo "$content" | sudo tee "$file" > /dev/null
        fi
    }

    # Helper function to create files
    create_file() {
        local file="$1"
        if [ "$test_mode" = "true" ]; then
            touch "$file"
        else
            sudo touch "$file"
        fi
    }

    # Create userconf for user setup (bypasses first-boot wizard)
    # Password needs to be encrypted using openssl
    local encrypted_pass=$(openssl passwd -6 "$password")
    write_file "$boot_mount/userconf.txt" "${username}:${encrypted_pass}"
    echo -e "${GREEN}✓ User configuration created${NC}"

    # Enable SSH
    create_file "$boot_mount/ssh"
    echo -e "${GREEN}✓ SSH enabled${NC}"

    # Create firstrun.sh for automated configuration
    if [ "$test_mode" = "true" ]; then
        cat << 'FIRSTRUN_SCRIPT' > "$boot_mount/firstrun.sh"
#!/bin/bash
# Raspberry Pi OS Bookworm first-run configuration script
# This script runs once on first boot to set up the kiosk

set -e

# Log all output
exec > >(tee -a /var/log/firstrun.log)
exec 2>&1

echo "Starting first-run configuration at $(date)"

# Set variables from boot partition files
BOOT_PATH="/boot/firmware"
if [ ! -d "$BOOT_PATH" ]; then
    BOOT_PATH="/boot"
fi

# Read configuration
if [ -f "$BOOT_PATH/kiosk-config.json" ]; then
    CONFIG_FILE="$BOOT_PATH/kiosk-config.json"
    KIOSK_URL=$(jq -r '.url' "$CONFIG_FILE")
    HOSTNAME=$(jq -r '.hostname' "$CONFIG_FILE")
    WIFI_SSID=$(jq -r '.wifi_ssid // empty' "$CONFIG_FILE")
    WIFI_PASSWORD=$(jq -r '.wifi_password // empty' "$CONFIG_FILE")
    WIFI_ENTERPRISE_USER=$(jq -r '.wifi_enterprise_user // empty' "$CONFIG_FILE")
    WIFI_ENTERPRISE_PASS=$(jq -r '.wifi_enterprise_pass // empty' "$CONFIG_FILE")
    TAILSCALE_AUTHKEY=$(jq -r '.tailscale_authkey // empty' "$CONFIG_FILE")
    USERNAME=$(jq -r '.username' "$CONFIG_FILE")
fi

# Set hostname
if [ -n "$HOSTNAME" ]; then
    echo "$HOSTNAME" > /etc/hostname
    sed -i "s/raspberrypi/$HOSTNAME/g" /etc/hosts
    echo "Set hostname to: $HOSTNAME"
fi

# Configure WiFi
if [ -n "$WIFI_SSID" ]; then
    echo "Configuring WiFi for SSID: $WIFI_SSID"
    
    # Enable WiFi
    rfkill unblock wifi || true
    
    # Configure WiFi country (required for WiFi to work)
    raspi-config nonint do_wifi_country US
    
    # Wait for NetworkManager to be ready
    systemctl start NetworkManager || true
    sleep 5
    
    if [ -n "$WIFI_ENTERPRISE_USER" ] && [ -n "$WIFI_ENTERPRISE_PASS" ]; then
        # Enterprise WiFi configuration using nmcli
        nmcli con add type wifi con-name "$WIFI_SSID" ifname wlan0 ssid "$WIFI_SSID" \
            wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2 \
            802-1x.identity "$WIFI_ENTERPRISE_USER" 802-1x.password "$WIFI_ENTERPRISE_PASS" \
            connection.autoconnect yes
    elif [ -n "$WIFI_PASSWORD" ]; then
        # Regular WPA2 WiFi - create NetworkManager connection file
        cat > "/etc/NetworkManager/system-connections/${WIFI_SSID}.nmconnection" << EOF
[connection]
id=$WIFI_SSID
uuid=$(uuidgen)
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$WIFI_PASSWORD

[ipv4]
method=auto

[ipv6]
method=auto
EOF
        chmod 600 "/etc/NetworkManager/system-connections/${WIFI_SSID}.nmconnection"
        systemctl restart NetworkManager || true
    fi
    
    echo "WiFi configured"
fi

# Install SSH key if provided
if [ -f "$BOOT_PATH/authorized_keys" ]; then
    echo "Installing SSH keys..."
    USER_HOME="/home/$USERNAME"
    mkdir -p "$USER_HOME/.ssh"
    cp "$BOOT_PATH/authorized_keys" "$USER_HOME/.ssh/authorized_keys"
    chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    rm -f "$BOOT_PATH/authorized_keys"
    echo "SSH keys installed"
fi

# Update system
echo "Updating package lists..."
apt-get update

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    chromium-browser \
    wayfire \
    wlr-randr \
    xwayland \
    seatd \
    libgles2-mesa \
    libgbm1 \
    libegl1-mesa \
    libgl1-mesa-dri \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    pulseaudio \
    pulseaudio-module-bluetooth \
    network-manager \
    jq \
    curl \
    uuid-runtime

# Add user to required groups
usermod -a -G video,render,input,audio "$USERNAME"

# Install and configure Tailscale if auth key provided
if [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    
    echo "Configuring Tailscale..."
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --hostname="$HOSTNAME" --accept-routes --accept-dns=false
    
    # Verify connection
    if tailscale status >/dev/null 2>&1; then
        echo "Tailscale connected successfully"
    else
        echo "Warning: Tailscale connection pending"
    fi
fi

# Configure Wayfire for kiosk mode
echo "Configuring Wayfire..."
USER_HOME="/home/$USERNAME"

# Create Wayfire config directory
mkdir -p "$USER_HOME/.config/wayfire"

# Create Wayfire configuration for kiosk mode
cat > "$USER_HOME/.config/wayfire/wayfire.ini" << 'EOF'
[core]
# List of plugins to load
plugins = autostart command vswitch

# Preferred decoration mode: server | client
preferred_decoration_mode = client

# How to position XWayland windows
xwayland_position = center

[autostart]
# Start PulseAudio
pulseaudio = /usr/bin/pulseaudio --start

# Hide cursor after 1 second of inactivity
hide_cursor = sh -c "sleep 5 && wlr-randr && unclutter -idle 1"

# Start Chromium in kiosk mode
chromium = /usr/local/bin/chromium-kiosk.sh

# Ensure proper display configuration
display_fix = /usr/local/bin/fix-displays.sh

[command]
# Emergency exit
binding_quit = <super> KEY_Q
command_quit = killall wayfire

[input]
# Disable cursor for kiosk mode
cursor_theme = none
cursor_size = 1

# Disable all input methods we don't need
xkb_layout = us
xkb_variant = 
xkb_options = 

# Mouse settings
mouse_accel_profile = flat
mouse_cursor_speed = 0

[output]
# Let Wayfire handle the output configuration
mode = preferred
position = 0,0
transform = normal
EOF

# Create chromium kiosk launcher script
cat > /usr/local/bin/chromium-kiosk.sh << EOF
#!/bin/bash
# Chromium kiosk launcher script

# Get URL from configuration
KIOSK_URL="$KIOSK_URL"

# Wait for Wayland to be ready
sleep 3

# Ensure audio is working
amixer set Master unmute 2>/dev/null || true
amixer set Master 80% 2>/dev/null || true

# Launch Chromium with optimal settings for kiosk mode
exec chromium-browser \\
    --kiosk \\
    --no-first-run \\
    --noerrdialogs \\
    --disable-infobars \\
    --disable-translate \\
    --disable-features=TranslateUI \\
    --disable-features=OverscrollHistoryNavigation \\
    --disable-pinch \\
    --overscroll-history-navigation=0 \\
    --disable-component-update \\
    --autoplay-policy=no-user-gesture-required \\
    --start-fullscreen \\
    --window-position=0,0 \\
    --check-for-update-interval=31536000 \\
    --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' \\
    --disable-software-rasterizer \\
    --enable-gpu-rasterization \\
    --enable-accelerated-video-decode \\
    --ignore-gpu-blocklist \\
    --enable-features=VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization \\
    --use-gl=egl \\
    --ozone-platform=wayland \\
    --enable-wayland-ime \\
    "\$KIOSK_URL"
EOF

chmod +x /usr/local/bin/chromium-kiosk.sh

# Create display fix script
cat > /usr/local/bin/fix-displays.sh << 'EOF'
#!/bin/bash
# Fix display configuration

sleep 2

# Get current display info
if command -v wlr-randr >/dev/null 2>&1; then
    # Log current outputs
    wlr-randr > /tmp/display-info.log 2>&1
    
    # Find the primary display (usually the one with highest resolution)
    PRIMARY=$(wlr-randr | grep -E "^[A-Z]+-[A-Z]-[0-9]" | head -1 | awk '{print $1}')
    
    if [ -n "$PRIMARY" ]; then
        # Enable primary display at preferred mode
        wlr-randr --output "$PRIMARY" --on --mode preferred
        
        # Disable any phantom displays
        for output in $(wlr-randr | grep -E "^[A-Z]+-[A-Z]-[0-9]" | awk '{print $1}'); do
            if [ "$output" != "$PRIMARY" ]; then
                # Check if it's a phantom display (usually shows as disconnected or has no EDID)
                if wlr-randr | grep -A5 "$output" | grep -q "Enabled: yes" && \
                   wlr-randr | grep -A5 "$output" | grep -qE "(unknown|disconnected|\(null\))"; then
                    wlr-randr --output "$output" --off
                fi
            fi
        done
    fi
fi
EOF

chmod +x /usr/local/bin/fix-displays.sh

# Set ownership
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config"

# Create systemd service for kiosk
cat > /etc/systemd/system/kiosk.service << EOF
[Unit]
Description=Wayfire Kiosk
After=multi-user.target systemd-user-sessions.service plymouth-quit-wait.service
Wants=network-online.target

[Service]
Type=simple
User=$USERNAME
Group=$USERNAME
PAMName=login

# Ensure runtime directory exists
RuntimeDirectory=user/1000
RuntimeDirectoryMode=0700

# Environment variables
Environment="HOME=/home/$USERNAME"
Environment="USER=$USERNAME"
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="XDG_SESSION_TYPE=wayland"
Environment="XDG_SESSION_CLASS=user"
Environment="XDG_SESSION_ID=1"
Environment="XDG_SEAT=seat0"
Environment="XDG_VTNR=1"

# Wayland/GPU settings
Environment="WLR_BACKENDS=drm"
Environment="WLR_DRM_NO_MODIFIERS=1"
Environment="WLR_RENDERER=gles2"
Environment="MESA_LOADER_DRIVER_OVERRIDE=v3d"

# Start Wayfire
ExecStartPre=/bin/mkdir -p /run/user/1000
ExecStartPre=/bin/chown $USERNAME:$USERNAME /run/user/1000
ExecStartPre=/bin/chmod 0700 /run/user/1000
ExecStartPre=/bin/loginctl enable-linger $USERNAME

ExecStart=/usr/bin/wayfire

# Restart policy
Restart=always
RestartSec=10

# Run on tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes

[Install]
WantedBy=graphical.target
EOF

# Disable conflicting services
systemctl disable getty@tty1.service
systemctl disable graphical.target || true

# Create URL management script
cat > /usr/local/bin/kiosk-set-url << 'EOF'
#!/bin/bash
# Script to update the kiosk URL

set -e

# Check if URL was provided
if [ $# -eq 0 ]; then
    echo "Usage: kiosk-set-url <url>"
    echo "Example: kiosk-set-url https://example.com"
    echo ""
    echo "Current URL:"
    grep "KIOSK_URL=" /usr/local/bin/chromium-kiosk.sh | cut -d'"' -f2
    exit 1
fi

NEW_URL="$1"

# Validate URL format
if ! [[ "$NEW_URL" =~ ^https?:// ]]; then
    echo "Error: Invalid URL format. URL must start with http:// or https://"
    exit 1
fi

# Update the URL in the chromium kiosk script
echo "Updating URL to: $NEW_URL"
sed -i "s|KIOSK_URL=\".*\"|KIOSK_URL=\"$NEW_URL\"|" /usr/local/bin/chromium-kiosk.sh

# Also update in boot config for persistence
if [ -f /boot/firmware/kiosk-url.txt ]; then
    echo "$NEW_URL" > /boot/firmware/kiosk-url.txt
fi

# Restart kiosk service
echo "Restarting kiosk service..."
systemctl restart kiosk.service

echo "✓ Kiosk URL updated successfully!"
EOF

chmod +x /usr/local/bin/kiosk-set-url

# Store URL for persistence
echo "$KIOSK_URL" > /boot/firmware/kiosk-url.txt

# Enable services
systemctl daemon-reload
systemctl enable kiosk.service

# Configure boot behavior
# Enable autologin on console (backup for kiosk service)
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
Type=idle
EOF

# Set default target
systemctl set-default multi-user.target

# Configure GPU settings for RPi 5
cat >> /boot/firmware/config.txt << EOF

# GPU Configuration for Kiosk Mode
gpu_mem=512
dtoverlay=vc4-kms-v3d-pi5
max_framebuffers=2

# Disable unnecessary hardware
dtparam=audio=on
dtoverlay=disable-bt

# Display settings
hdmi_force_hotplug=1
config_hdmi_boost=7
EOF

# Enable required overlays
sed -i 's/^#dtparam=i2c_arm=on/dtparam=i2c_arm=on/' /boot/firmware/config.txt || true

# Clean up
rm -f "$BOOT_PATH/firstrun.sh"
rm -f "$BOOT_PATH/kiosk-config.json"
rm -f "$BOOT_PATH/userconf.txt"

# Remove firstrun.sh from cmdline.txt
if [ -f "$BOOT_PATH/cmdline.txt" ]; then
    sed -i 's| systemd.run=/boot/firstrun.sh||g' "$BOOT_PATH/cmdline.txt"
    sed -i 's| systemd.run=/boot/firmware/firstrun.sh||g' "$BOOT_PATH/cmdline.txt"
    sed -i 's| systemd.run_success_action=reboot||g' "$BOOT_PATH/cmdline.txt"
    sed -i 's| systemd.unit=kernel-command-line.target||g' "$BOOT_PATH/cmdline.txt"
elif [ -f "/boot/cmdline.txt" ]; then
    sed -i 's| systemd.run=/boot/firstrun.sh||g' /boot/cmdline.txt
    sed -i 's| systemd.run=/boot/firmware/firstrun.sh||g' /boot/cmdline.txt
    sed -i 's| systemd.run_success_action=reboot||g' /boot/cmdline.txt
    sed -i 's| systemd.unit=kernel-command-line.target||g' /boot/cmdline.txt
fi

echo "First-run configuration complete at $(date)"
echo "System will reboot in 10 seconds..."
sleep 10
reboot
FIRSTRUN_SCRIPT
    else
        cat << 'FIRSTRUN_SCRIPT' | sudo tee "$boot_mount/firstrun.sh" > /dev/null
#!/bin/bash
# Raspberry Pi OS Bookworm first-run configuration script
# This script runs once on first boot to set up the kiosk

set -e

# Log all output
exec > >(tee -a /var/log/firstrun.log)
exec 2>&1

echo "Starting first-run configuration at $(date)"

# Set variables from boot partition files
BOOT_PATH="/boot/firmware"
if [ ! -d "$BOOT_PATH" ]; then
    BOOT_PATH="/boot"
fi

# Read configuration
if [ -f "$BOOT_PATH/kiosk-config.json" ]; then
    CONFIG_FILE="$BOOT_PATH/kiosk-config.json"
    KIOSK_URL=$(jq -r '.url' "$CONFIG_FILE")
    HOSTNAME=$(jq -r '.hostname' "$CONFIG_FILE")
    WIFI_SSID=$(jq -r '.wifi_ssid // empty' "$CONFIG_FILE")
    WIFI_PASSWORD=$(jq -r '.wifi_password // empty' "$CONFIG_FILE")
    WIFI_ENTERPRISE_USER=$(jq -r '.wifi_enterprise_user // empty' "$CONFIG_FILE")
    WIFI_ENTERPRISE_PASS=$(jq -r '.wifi_enterprise_pass // empty' "$CONFIG_FILE")
    TAILSCALE_AUTHKEY=$(jq -r '.tailscale_authkey // empty' "$CONFIG_FILE")
    USERNAME=$(jq -r '.username' "$CONFIG_FILE")
fi

# Set hostname
if [ -n "$HOSTNAME" ]; then
    echo "$HOSTNAME" > /etc/hostname
    sed -i "s/raspberrypi/$HOSTNAME/g" /etc/hosts
    echo "Set hostname to: $HOSTNAME"
fi

# Configure WiFi
if [ -n "$WIFI_SSID" ]; then
    echo "Configuring WiFi for SSID: $WIFI_SSID"
    
    # Enable WiFi
    rfkill unblock wifi || true
    
    # Configure WiFi country (required for WiFi to work)
    raspi-config nonint do_wifi_country US
    
    # Wait for NetworkManager to be ready
    systemctl start NetworkManager || true
    sleep 5
    
    if [ -n "$WIFI_ENTERPRISE_USER" ] && [ -n "$WIFI_ENTERPRISE_PASS" ]; then
        # Enterprise WiFi configuration using nmcli
        nmcli con add type wifi con-name "$WIFI_SSID" ifname wlan0 ssid "$WIFI_SSID" \
            wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2 \
            802-1x.identity "$WIFI_ENTERPRISE_USER" 802-1x.password "$WIFI_ENTERPRISE_PASS" \
            connection.autoconnect yes
    elif [ -n "$WIFI_PASSWORD" ]; then
        # Regular WPA2 WiFi - create NetworkManager connection file
        cat > "/etc/NetworkManager/system-connections/${WIFI_SSID}.nmconnection" << EOF
[connection]
id=$WIFI_SSID
uuid=$(uuidgen)
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$WIFI_PASSWORD

[ipv4]
method=auto

[ipv6]
method=auto
EOF
        chmod 600 "/etc/NetworkManager/system-connections/${WIFI_SSID}.nmconnection"
        systemctl restart NetworkManager || true
    fi
    
    echo "WiFi configured"
fi

# Install SSH key if provided
if [ -f "$BOOT_PATH/authorized_keys" ]; then
    echo "Installing SSH keys..."
    USER_HOME="/home/$USERNAME"
    mkdir -p "$USER_HOME/.ssh"
    cp "$BOOT_PATH/authorized_keys" "$USER_HOME/.ssh/authorized_keys"
    chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    rm -f "$BOOT_PATH/authorized_keys"
    echo "SSH keys installed"
fi

# Update system
echo "Updating package lists..."
apt-get update

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    chromium-browser \
    wayfire \
    wlr-randr \
    xwayland \
    seatd \
    libgles2-mesa \
    libgbm1 \
    libegl1-mesa \
    libgl1-mesa-dri \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    pulseaudio \
    pulseaudio-module-bluetooth \
    network-manager \
    jq \
    curl \
    uuid-runtime

# Add user to required groups
usermod -a -G video,render,input,audio "$USERNAME"

# Install and configure Tailscale if auth key provided
if [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    
    echo "Configuring Tailscale..."
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --hostname="$HOSTNAME" --accept-routes --accept-dns=false
    
    # Verify connection
    if tailscale status >/dev/null 2>&1; then
        echo "Tailscale connected successfully"
    else
        echo "Warning: Tailscale connection pending"
    fi
fi

# Configure Wayfire for kiosk mode
echo "Configuring Wayfire..."
USER_HOME="/home/$USERNAME"

# Create Wayfire config directory
mkdir -p "$USER_HOME/.config/wayfire"

# Create Wayfire configuration for kiosk mode
cat > "$USER_HOME/.config/wayfire/wayfire.ini" << 'EOF'
[core]
# List of plugins to load
plugins = autostart command vswitch

# Preferred decoration mode: server | client
preferred_decoration_mode = client

# How to position XWayland windows
xwayland_position = center

[autostart]
# Start PulseAudio
pulseaudio = /usr/bin/pulseaudio --start

# Hide cursor after 1 second of inactivity
hide_cursor = sh -c "sleep 5 && wlr-randr && unclutter -idle 1"

# Start Chromium in kiosk mode
chromium = /usr/local/bin/chromium-kiosk.sh

# Ensure proper display configuration
display_fix = /usr/local/bin/fix-displays.sh

[command]
# Emergency exit
binding_quit = <super> KEY_Q
command_quit = killall wayfire

[input]
# Disable cursor for kiosk mode
cursor_theme = none
cursor_size = 1

# Disable all input methods we don't need
xkb_layout = us
xkb_variant = 
xkb_options = 

# Mouse settings
mouse_accel_profile = flat
mouse_cursor_speed = 0

[output]
# Let Wayfire handle the output configuration
mode = preferred
position = 0,0
transform = normal
EOF

# Create chromium kiosk launcher script
cat > /usr/local/bin/chromium-kiosk.sh << EOF
#!/bin/bash
# Chromium kiosk launcher script

# Get URL from configuration
KIOSK_URL="$KIOSK_URL"

# Wait for Wayland to be ready
sleep 3

# Ensure audio is working
amixer set Master unmute 2>/dev/null || true
amixer set Master 80% 2>/dev/null || true

# Launch Chromium with optimal settings for kiosk mode
exec chromium-browser \\
    --kiosk \\
    --no-first-run \\
    --noerrdialogs \\
    --disable-infobars \\
    --disable-translate \\
    --disable-features=TranslateUI \\
    --disable-features=OverscrollHistoryNavigation \\
    --disable-pinch \\
    --overscroll-history-navigation=0 \\
    --disable-component-update \\
    --autoplay-policy=no-user-gesture-required \\
    --start-fullscreen \\
    --window-position=0,0 \\
    --check-for-update-interval=31536000 \\
    --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' \\
    --disable-software-rasterizer \\
    --enable-gpu-rasterization \\
    --enable-accelerated-video-decode \\
    --ignore-gpu-blocklist \\
    --enable-features=VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization \\
    --use-gl=egl \\
    --ozone-platform=wayland \\
    --enable-wayland-ime \\
    "\$KIOSK_URL"
EOF

chmod +x /usr/local/bin/chromium-kiosk.sh

# Create display fix script
cat > /usr/local/bin/fix-displays.sh << 'EOF'
#!/bin/bash
# Fix display configuration

sleep 2

# Get current display info
if command -v wlr-randr >/dev/null 2>&1; then
    # Log current outputs
    wlr-randr > /tmp/display-info.log 2>&1
    
    # Find the primary display (usually the one with highest resolution)
    PRIMARY=$(wlr-randr | grep -E "^[A-Z]+-[A-Z]-[0-9]" | head -1 | awk '{print $1}')
    
    if [ -n "$PRIMARY" ]; then
        # Enable primary display at preferred mode
        wlr-randr --output "$PRIMARY" --on --mode preferred
        
        # Disable any phantom displays
        for output in $(wlr-randr | grep -E "^[A-Z]+-[A-Z]-[0-9]" | awk '{print $1}'); do
            if [ "$output" != "$PRIMARY" ]; then
                # Check if it's a phantom display (usually shows as disconnected or has no EDID)
                if wlr-randr | grep -A5 "$output" | grep -q "Enabled: yes" && \
                   wlr-randr | grep -A5 "$output" | grep -qE "(unknown|disconnected|\(null\))"; then
                    wlr-randr --output "$output" --off
                fi
            fi
        done
    fi
fi
EOF

chmod +x /usr/local/bin/fix-displays.sh

# Set ownership
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config"

# Create systemd service for kiosk
cat > /etc/systemd/system/kiosk.service << EOF
[Unit]
Description=Wayfire Kiosk
After=multi-user.target systemd-user-sessions.service plymouth-quit-wait.service
Wants=network-online.target

[Service]
Type=simple
User=$USERNAME
Group=$USERNAME
PAMName=login

# Ensure runtime directory exists
RuntimeDirectory=user/1000
RuntimeDirectoryMode=0700

# Environment variables
Environment="HOME=/home/$USERNAME"
Environment="USER=$USERNAME"
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="XDG_SESSION_TYPE=wayland"
Environment="XDG_SESSION_CLASS=user"
Environment="XDG_SESSION_ID=1"
Environment="XDG_SEAT=seat0"
Environment="XDG_VTNR=1"

# Wayland/GPU settings
Environment="WLR_BACKENDS=drm"
Environment="WLR_DRM_NO_MODIFIERS=1"
Environment="WLR_RENDERER=gles2"
Environment="MESA_LOADER_DRIVER_OVERRIDE=v3d"

# Start Wayfire
ExecStartPre=/bin/mkdir -p /run/user/1000
ExecStartPre=/bin/chown $USERNAME:$USERNAME /run/user/1000
ExecStartPre=/bin/chmod 0700 /run/user/1000
ExecStartPre=/bin/loginctl enable-linger $USERNAME

ExecStart=/usr/bin/wayfire

# Restart policy
Restart=always
RestartSec=10

# Run on tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes

[Install]
WantedBy=graphical.target
EOF

# Disable conflicting services
systemctl disable getty@tty1.service
systemctl disable graphical.target || true

# Create URL management script
cat > /usr/local/bin/kiosk-set-url << 'EOF'
#!/bin/bash
# Script to update the kiosk URL

set -e

# Check if URL was provided
if [ $# -eq 0 ]; then
    echo "Usage: kiosk-set-url <url>"
    echo "Example: kiosk-set-url https://example.com"
    echo ""
    echo "Current URL:"
    grep "KIOSK_URL=" /usr/local/bin/chromium-kiosk.sh | cut -d'"' -f2
    exit 1
fi

NEW_URL="$1"

# Validate URL format
if ! [[ "$NEW_URL" =~ ^https?:// ]]; then
    echo "Error: Invalid URL format. URL must start with http:// or https://"
    exit 1
fi

# Update the URL in the chromium kiosk script
echo "Updating URL to: $NEW_URL"
sed -i "s|KIOSK_URL=\".*\"|KIOSK_URL=\"$NEW_URL\"|" /usr/local/bin/chromium-kiosk.sh

# Also update in boot config for persistence
if [ -f /boot/firmware/kiosk-url.txt ]; then
    echo "$NEW_URL" > /boot/firmware/kiosk-url.txt
fi

# Restart kiosk service
echo "Restarting kiosk service..."
systemctl restart kiosk.service

echo "✓ Kiosk URL updated successfully!"
EOF

chmod +x /usr/local/bin/kiosk-set-url

# Store URL for persistence
echo "$KIOSK_URL" > /boot/firmware/kiosk-url.txt

# Enable services
systemctl daemon-reload
systemctl enable kiosk.service

# Configure boot behavior
# Enable autologin on console (backup for kiosk service)
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
Type=idle
EOF

# Set default target
systemctl set-default multi-user.target

# Configure GPU settings for RPi 5
cat >> /boot/firmware/config.txt << EOF

# GPU Configuration for Kiosk Mode
gpu_mem=512
dtoverlay=vc4-kms-v3d-pi5
max_framebuffers=2

# Disable unnecessary hardware
dtparam=audio=on
dtoverlay=disable-bt

# Display settings
hdmi_force_hotplug=1
config_hdmi_boost=7
EOF

# Enable required overlays
sed -i 's/^#dtparam=i2c_arm=on/dtparam=i2c_arm=on/' /boot/firmware/config.txt || true

# Clean up
rm -f "$BOOT_PATH/firstrun.sh"
rm -f "$BOOT_PATH/kiosk-config.json"
rm -f "$BOOT_PATH/userconf.txt"

# Remove firstrun.sh from cmdline.txt
if [ -f "$BOOT_PATH/cmdline.txt" ]; then
    sed -i 's| systemd.run=/boot/firstrun.sh||g' "$BOOT_PATH/cmdline.txt"
    sed -i 's| systemd.run=/boot/firmware/firstrun.sh||g' "$BOOT_PATH/cmdline.txt"
    sed -i 's| systemd.run_success_action=reboot||g' "$BOOT_PATH/cmdline.txt"
    sed -i 's| systemd.unit=kernel-command-line.target||g' "$BOOT_PATH/cmdline.txt"
elif [ -f "/boot/cmdline.txt" ]; then
    sed -i 's| systemd.run=/boot/firstrun.sh||g' /boot/cmdline.txt
    sed -i 's| systemd.run=/boot/firmware/firstrun.sh||g' /boot/cmdline.txt
    sed -i 's| systemd.run_success_action=reboot||g' /boot/cmdline.txt
    sed -i 's| systemd.unit=kernel-command-line.target||g' /boot/cmdline.txt
fi

echo "First-run configuration complete at $(date)"
echo "System will reboot in 10 seconds..."
sleep 10
reboot
FIRSTRUN_SCRIPT
        sudo chmod +x "$boot_mount/firstrun.sh"
    fi

    if [ "$test_mode" = "true" ]; then
        chmod +x "$boot_mount/firstrun.sh"
    else
        sudo chmod +x "$boot_mount/firstrun.sh"
    fi

    # Create configuration file with all settings
    local config_content=$(cat << EOF
{
    "url": "$url",
    "hostname": "$hostname",
    "username": "$username",
    "wifi_ssid": "$wifi_ssid",
    "wifi_password": "$wifi_password",
    "wifi_enterprise_user": "$wifi_enterprise_user",
    "wifi_enterprise_pass": "$wifi_enterprise_pass",
    "tailscale_authkey": "$tailscale_authkey"
}
EOF
)
    write_file "$boot_mount/kiosk-config.json" "$config_content"

    # Copy SSH key if provided
    if [ -f "$ssh_key_file" ]; then
        if [ "$test_mode" = "true" ]; then
            cp "$ssh_key_file" "$boot_mount/authorized_keys"
        else
            sudo cp "$ssh_key_file" "$boot_mount/authorized_keys"
        fi
        echo -e "${GREEN}✓ SSH key configured${NC}"
    fi

    # Modify cmdline.txt to run firstrun.sh
    local cmdline_file="$boot_mount/cmdline.txt"
    if [ "$test_mode" = "true" ]; then
        # In test mode, create a sample cmdline.txt
        echo "console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 fsck.repair=yes rootwait" > "$cmdline_file"
    fi
    
    if [ -f "$cmdline_file" ]; then
        # Read current cmdline.txt
        local current_cmdline=$(cat "$cmdline_file")
        # Append firstrun.sh execution
        local new_cmdline="$current_cmdline systemd.run=/boot/firmware/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target"
        
        if [ "$test_mode" = "true" ]; then
            echo -n "$new_cmdline" > "$cmdline_file"
        else
            echo -n "$new_cmdline" | sudo tee "$cmdline_file" > /dev/null
        fi
        echo -e "${GREEN}✓ Boot configuration updated${NC}"
    else
        echo -e "${RED}Error: cmdline.txt not found${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Raspberry Pi OS configuration complete${NC}"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Configuration Options:
    --url <url>                  URL to display in kiosk mode (default: https://panic.fly.dev/)
    --hostname <name>            Hostname for the Raspberry Pi (default: panic-rpi)
    --username <user>            Username for the admin account (default: pi)
    --password <pass>            Password for the admin account (default: raspberry)

Network Options (optional):
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK networks)
    --wifi-enterprise-user <u>   Enterprise WiFi username (use with --wifi-ssid)
    --wifi-enterprise-pass <p>   Enterprise WiFi password (use with --wifi-ssid)
    --tailscale-authkey <key>    Tailscale auth key for automatic join

Optional:
    --ssh-key <path>             Path to SSH public key for passwordless login
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

    # Parse arguments - with sensible defaults
    local url="$DEFAULT_URL"
    local wifi_ssid=""
    local wifi_password=""
    local wifi_enterprise_user=""
    local wifi_enterprise_pass=""
    local hostname="panic-rpi"
    local username="pi"
    local password="raspberry"
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

    # Check required tools (skip in test mode since we don't need all tools)
    if [ "$test_mode" != "true" ]; then
        check_required_tools
    fi

    # Show configuration
    echo -e "${GREEN}Raspberry Pi OS Kiosk SD Card Setup${NC}"
    echo "====================================="
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
        # Get device info for confirmation
        local device_size=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1 || echo "0")
        local device_size_gb=$((device_size / 1024 / 1024 / 1024))
        local device_model=$(lsblk -n -o MODEL "$device" 2>/dev/null | tr -d ' ' || echo "Unknown")
        
        echo -e "${YELLOW}WARNING: This will ERASE all data on $device${NC}"
        echo -e "${YELLOW}Device: $device - ${device_size_gb}GB - $device_model${NC}"
        echo -e "${RED}ALL DATA ON THIS DEVICE WILL BE LOST!${NC}"
        read -p "Continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    # Download Raspberry Pi OS image
    local temp_image="/tmp/raspios-$$.img.xz"
    download_raspios "$temp_image"

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
    configure_raspios "$boot_mount" "$wifi_ssid" "$wifi_password" \
        "$wifi_enterprise_user" "$wifi_enterprise_pass" "$url" \
        "$hostname" "$username" "$password" "$tailscale_authkey" \
        "$ssh_key_file" "$test_mode"

    # Cleanup
    if [ "$test_mode" = "true" ]; then
        echo ""
        echo -e "${YELLOW}TEST MODE: Generated files in: $boot_mount${NC}"
        echo "Contents:"
        ls -la "$boot_mount"
        echo ""
        echo -e "${GREEN}✓ TEST MODE: Configuration test complete!${NC}"
    else
        # Unmount boot partition
        sudo umount "$boot_mount" || true
        rmdir "$boot_mount" 2>/dev/null || true
        
        # Sync and eject
        echo -e "${YELLOW}Syncing data...${NC}"
        sudo sync
        
        echo -e "${GREEN}✓ SD card ready!${NC}"
        echo -e "${GREEN}You can now safely remove the SD card.${NC}"
    fi

    echo ""
    echo "Next steps:"
    echo "1. Insert the SD card into your Raspberry Pi 5"
    echo "2. Connect Ethernet cable for initial setup (if using WiFi)"
    echo "3. Power on the Pi"
    echo "4. Wait 5-10 minutes for Raspberry Pi OS to:"
    echo "   - Complete first-boot configuration"
    echo "   - Connect to WiFi (if configured)"
    echo "   - Install required packages"
    echo "   - Join Tailscale network (if configured)"
    echo "   - Configure and start kiosk mode"
    echo "   - Reboot into kiosk display"
    echo ""
    if [ -n "$tailscale_authkey" ]; then
        echo "5. Verify the Pi is on Tailscale:"
        echo "   tailscale status | grep $hostname"
        echo ""
        echo "6. You can SSH to the Pi via Tailscale:"
        echo "   tailscale ssh $username@$hostname"
    else
        echo "5. You can SSH to the Pi when it's online:"
        echo "   ssh $username@<pi-ip-address>"
    fi
    echo ""
    echo "To change the kiosk URL after setup:"
    echo "   sudo kiosk-set-url https://new-url.com"
}

# Run main function
main "$@"