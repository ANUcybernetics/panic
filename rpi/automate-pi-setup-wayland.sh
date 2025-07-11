#!/bin/bash
# Raspberry Pi OS automated SD card setup for kiosk mode with 4K support
# This script creates a fully automated Raspberry Pi OS installation that boots directly into Chromium kiosk mode on Wayland

set -e
set -u
set -o pipefail

# Configuration
readonly RASPI_IMAGE_URL="https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64.img.xz"
readonly CACHE_DIR="$HOME/.cache/raspi-images"

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

# Check for required tools and install if needed
check_and_install_tools() {
    # Check for jq
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}jq not found. Installing via Homebrew...${NC}"

        # Check if Homebrew is installed
        if ! command -v brew >/dev/null 2>&1; then
            echo -e "${RED}Error: Homebrew is required to install jq${NC}"
            echo "Install Homebrew from https://brew.sh"
            exit 1
        fi

        brew install jq
        echo -e "${GREEN}✓ jq installed${NC}"
    fi

    # Check for pv (optional but helpful)
    if ! command -v pv >/dev/null 2>&1; then
        echo -e "${YELLOW}Tip: Install 'pv' for progress display: brew install pv${NC}"
    fi
}

# Function to find SD card device (same as DietPi version)
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

# Function to download Raspberry Pi OS image with caching
download_raspi_os() {
    local output_file="$1"

    # Create cache directory if it doesn't exist
    mkdir -p "$CACHE_DIR"

    # Extract filename from URL
    local filename=$(basename "$RASPI_IMAGE_URL")
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

    echo -e "${YELLOW}Downloading Raspberry Pi OS image...${NC}"
    if ! curl -L -o "$cached_file" "$RASPI_IMAGE_URL"; then
        echo -e "${RED}Error: Failed to download image from $RASPI_IMAGE_URL${NC}"
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

# Function to write image to SD card (same as DietPi version)
write_image_to_sd() {
    local image_file="$1"
    local device="$2"

    echo -e "${YELLOW}Writing image to SD card...${NC}"
    echo "This will take several minutes..."

    # Prompt for sudo password early to avoid interrupting the progress display
    echo "Requesting administrator privileges for writing to SD card..."
    sudo -v

    # Unmount any mounted partitions
    diskutil unmountDisk force "$device" || true

    # Decompress and write in one step
    echo "Decompressing and writing image..."

    # Check if pv is available for progress display
    if command -v pv >/dev/null 2>&1; then
        # Get uncompressed size for progress bar (handle MiB/GiB units)
        local uncompressed_size=$(xz -l "$image_file" 2>/dev/null | awk 'NR==2 {
            # Remove commas from the size field
            gsub(",", "", $5);
            size=$5;
            unit=$6;
            if (unit == "MiB") 
                print int(size * 1024 * 1024);
            else if (unit == "GiB")
                print int(size * 1024 * 1024 * 1024);
            else
                print size;
        }')

        # Fallback to known sizes if xz -l fails
        if [ -z "$uncompressed_size" ] || [ "$uncompressed_size" -eq 0 ] 2>/dev/null; then
            # Try to determine size based on filename
            case "$image_file" in
                *raspios*2025-05-13*)
                    # Raspberry Pi OS 2025-05-13 is approximately 5.8GB uncompressed
                    uncompressed_size=$((5800 * 1024 * 1024))
                    echo "Using known size for Raspberry Pi OS 2025-05-13..."
                    ;;
                *)
                    uncompressed_size=""
                    ;;
            esac
        fi

        if [ -n "$uncompressed_size" ] && [ "$uncompressed_size" -gt 0 ] 2>/dev/null; then
            echo "Using pv for progress display with ETA..."
            xzcat "$image_file" | pv -s "$uncompressed_size" | sudo dd of="$device" bs=4m
        else
            # Fallback if we can't get size
            echo "Using pv for progress display (size unknown)..."
            xzcat "$image_file" | pv | sudo dd of="$device" bs=4m
        fi
    else
        echo "Tip: Install 'pv' (brew install pv) to see progress"
        echo "You can press Ctrl+T to see current progress"
        xzcat "$image_file" | sudo dd of="$device" bs=4m
    fi

    # Ensure all data is written
    sync

    echo -e "${GREEN}✓ Image written successfully${NC}"
}

# Function to generate password hash for userconf
generate_password_hash() {
    local password="$1"
    # Use openssl to generate a SHA-512 password hash
    echo "$password" | openssl passwd -6 -stdin
}

# Function to create the firstrun script content with JSON configuration
create_firstrun_script() {
    local config_json="$1"
    local ssh_key="$2"
    
    # Base64 encode the JSON to avoid any escaping issues
    local config_b64=$(echo -n "$config_json" | base64)
    
    # Output the script with base64 config embedded
    cat <<EOF
#!/bin/bash
# First-run script for Raspberry Pi OS kiosk setup

set -e

# Configuration passed as base64-encoded JSON
CONFIG_B64="$config_b64"
CONFIG_JSON=\$(echo "\$CONFIG_B64" | base64 -d)

# Install jq for JSON parsing
echo "Installing jq for configuration parsing..."
apt-get update
apt-get install -y jq

# Parse configuration
HOSTNAME=$(echo "$CONFIG_JSON" | jq -r '.hostname')
USERNAME=$(echo "$CONFIG_JSON" | jq -r '.username')
URL=$(echo "$CONFIG_JSON" | jq -r '.url')
TAILSCALE_AUTHKEY=$(echo "$CONFIG_JSON" | jq -r '.tailscale_authkey // empty')

# Set hostname
hostnamectl set-hostname "$HOSTNAME"
sed -i "s/raspberrypi/$HOSTNAME/g" /etc/hosts

# Setup SSH key if provided
SSH_KEY_B64="${ssh_key}"
if [ -n "$SSH_KEY_B64" ]; then
    echo "Setting up SSH key for $USERNAME..."
    mkdir -p /home/$USERNAME/.ssh
    echo "$SSH_KEY_B64" | base64 -d > /home/$USERNAME/.ssh/authorized_keys
    chmod 700 /home/$USERNAME/.ssh
    chmod 600 /home/$USERNAME/.ssh/authorized_keys
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
    echo "SSH key configured"
fi

# Wait for network
echo "Waiting for network connectivity..."
while ! ping -c 1 google.com > /dev/null 2>&1; do
    sleep 2
done

# Install required packages
echo "Installing required packages..."
apt-get install -y chromium-browser unclutter xinit xserver-xorg-video-all xserver-xorg-input-all wayfire

# Install and configure Tailscale if auth key provided
if [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --hostname="$HOSTNAME"
    echo "Tailscale installed and connected"
fi

# Create kiosk service
cat > /etc/systemd/system/kiosk.service <<EOF
[Unit]
Description=Chromium Kiosk Mode
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/chromium-kiosk.sh
User=$USERNAME
Group=$USERNAME
Restart=always
RestartSec=5
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="WAYLAND_DISPLAY=wayland-1"

[Install]
WantedBy=graphical.target
EOF

# Create chromium kiosk script
mkdir -p /usr/local/bin
cat > /usr/local/bin/chromium-kiosk.sh <<'EOF'
#!/bin/bash
# Chromium kiosk script for Wayland

# Get URL from file or use default
URL=$(cat /boot/firmware/kiosk_url.txt 2>/dev/null || echo "https://panic.fly.dev")

# Wait for Wayland to be ready
sleep 5

# Hide mouse cursor
unclutter -idle 0.1 -root &

# Get display resolution
RESOLUTION=""
if [ -f /sys/class/graphics/fb0/virtual_size ]; then
    RESOLUTION=$(cat /sys/class/graphics/fb0/virtual_size | tr ',' 'x')
fi

# Default to 1920x1080 if detection fails
if [ -z "$RESOLUTION" ]; then
    RESOLUTION="1920x1080"
fi

RES_X=$(echo "$RESOLUTION" | cut -d'x' -f1)
RES_Y=$(echo "$RESOLUTION" | cut -d'x' -f2)
CHROMIUM_RES="${RES_X},${RES_Y}"

echo "Using resolution: $CHROMIUM_RES" | tee /var/log/chromium-kiosk.log

# Launch Chromium in kiosk mode with Wayland support
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
    --window-size=$CHROMIUM_RES \
    --window-position=0,0 \
    --disable-features=OverscrollHistoryNavigation \
    --disable-pinch \
    --check-for-update-interval=31536000 \
    --disable-component-update \
    --autoplay-policy=no-user-gesture-required \
    --enable-features=UseOzonePlatform \
    --ozone-platform=wayland \
    --in-process-gpu \
    "$URL"
EOF

chmod +x /usr/local/bin/chromium-kiosk.sh

# Create kiosk-url helper script
cat > /usr/local/bin/kiosk-url <<'EOF'
#!/bin/bash
# Simple script to change the kiosk URL

if [ $# -eq 0 ]; then
    echo "Current kiosk URL:"
    cat /boot/firmware/kiosk_url.txt 2>/dev/null || echo "https://panic.fly.dev (default)"
    echo ""
    echo "Usage: kiosk-url <new-url>"
    echo "Example: kiosk-url https://example.com"
    exit 0
fi

NEW_URL="$1"

# Update the URL
echo "$NEW_URL" | sudo tee /boot/firmware/kiosk_url.txt > /dev/null

echo "Kiosk URL changed to: $NEW_URL"
echo "Restarting kiosk..."

# Restart the kiosk service
sudo systemctl restart kiosk

echo "Done! The kiosk should now display: $NEW_URL"
EOF

chmod +x /usr/local/bin/kiosk-url

# Configure auto-login
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
EOF

# Configure Wayfire as compositor (lightweight for kiosk)
apt-get install -y wayfire

# Create Wayfire config for kiosk
mkdir -p /home/$USERNAME/.config/wayfire
cat > /home/$USERNAME/.config/wayfire/wayfire.ini <<'EOF'
[core]
plugins = autostart

[autostart]
chromium = /usr/local/bin/chromium-kiosk.sh

[input]
xkb_layout = us
cursor_theme = none
cursor_size = 1
EOF

chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

# Set up automatic Wayland session start
cat > /home/$USERNAME/.bash_profile <<'EOF'
# Auto-start Wayfire on tty1
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec wayfire
fi
EOF

chown $USERNAME:$USERNAME /home/$USERNAME/.bash_profile

# Enable services
systemctl enable kiosk
systemctl set-default graphical.target

# Store the URL
echo "$URL" > /boot/firmware/kiosk_url.txt

# Clean up
rm -f /boot/firmware/firstrun.sh

# Reboot into kiosk mode
echo "Setup complete! Rebooting into kiosk mode..."
sleep 3
reboot
EOF
}

# Function to configure Raspberry Pi OS
configure_raspi_os() {
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

    echo -e "${YELLOW}Configuring Raspberry Pi OS...${NC}"

    # Enable SSH
    touch "$boot_mount/ssh"
    echo -e "${GREEN}✓ SSH enabled${NC}"

    # Set up user account (userconf.txt)
    local password_hash=$(generate_password_hash "$password")
    echo "${username}:${password_hash}" > "$boot_mount/userconf.txt"
    echo -e "${GREEN}✓ User account configured${NC}"

    # Configure WiFi
    if [ -n "$wifi_ssid" ]; then
        if [ -n "$wifi_enterprise_user" ] && [ -n "$wifi_enterprise_pass" ]; then
            # Enterprise WiFi
            cat > "$boot_mount/wpa_supplicant.conf" << EOF
country=AU
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$wifi_ssid"
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="$wifi_enterprise_user"
    password="$wifi_enterprise_pass"
    phase1="peaplabel=0"
    phase2="auth=MSCHAPV2"
}
EOF
        elif [ -n "$wifi_password" ]; then
            # Regular WiFi
            cat > "$boot_mount/wpa_supplicant.conf" << EOF
country=AU
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$wifi_ssid"
    psk="$wifi_password"
}
EOF
        fi
        echo -e "${GREEN}✓ WiFi configured${NC}"
    fi

    # Configure config.txt for better 4K support
    cat >> "$boot_mount/config.txt" << EOF

# Enable 4K60 support
hdmi_enable_4kp60=1

# GPU memory for 4K support
gpu_mem=256

# Enable Wayland
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Disable overscan
disable_overscan=1

# Force HDMI hotplug
hdmi_force_hotplug=1
EOF
    echo -e "${GREEN}✓ Display settings configured for 4K${NC}"

    # Create configuration JSON (compact to avoid newlines)
    local config_json=$(jq -n -c \
        --arg hostname "$hostname" \
        --arg username "$username" \
        --arg url "$url" \
        --arg tailscale "$tailscale_authkey" \
        '{hostname: $hostname, username: $username, url: $url, tailscale_authkey: $tailscale}')

    # Read SSH public key if it exists and base64 encode it
    local ssh_key_b64=""
    if [ -f "$ssh_key_file" ]; then
        ssh_key_b64=$(cat "$ssh_key_file" | base64)
        echo -e "${GREEN}✓ Found SSH key: $(basename "$ssh_key_file")${NC}"
    else
        echo -e "${YELLOW}Note: No SSH key found at $ssh_key_file${NC}"
        echo -e "${YELLOW}      Password authentication will be used${NC}"
    fi

    # Create the first-run script with embedded JSON configuration and SSH key
    create_firstrun_script "$config_json" "$ssh_key_b64" > "$boot_mount/firstrun.sh"
    chmod +x "$boot_mount/firstrun.sh"

    # Raspberry Pi OS expects firstrun.sh in the root of boot partition
    # and it must follow specific conventions
    mv "$boot_mount/firstrun.sh" "$boot_mount/firstrun_custom.sh"
    chmod +x "$boot_mount/firstrun_custom.sh"

    # Create the official firstrun.sh that Raspberry Pi OS will execute
    cat > "$boot_mount/firstrun.sh" << 'OFFICIAL_FIRSTRUN'
#!/bin/bash

set +e

# This script is executed by Raspberry Pi OS on first boot
# It runs as root with the filesystem fully available

# Run our custom setup script
if [ -f /boot/firmware/firstrun_custom.sh ]; then
    echo "Running custom first boot setup..."
    bash /boot/firmware/firstrun_custom.sh 2>&1 | tee /var/log/firstrun_custom.log

    # Clean up
    rm -f /boot/firmware/firstrun_custom.sh
    rm -f /boot/firmware/firstrun
fi

# Remove this script to prevent running again
rm -f /boot/firmware/firstrun.sh

exit 0
OFFICIAL_FIRSTRUN

    chmod +x "$boot_mount/firstrun.sh"

    # Also need to modify cmdline.txt to trigger firstrun
    # Raspberry Pi OS looks for systemd.run_success_action=reboot systemd.run=/boot/firmware/firstrun.sh
    cp "$boot_mount/cmdline.txt" "$boot_mount/cmdline.txt.bak"
    echo -n " systemd.run_success_action=reboot systemd.run=/boot/firmware/firstrun.sh" >> "$boot_mount/cmdline.txt"

    echo -e "${GREEN}✓ Raspberry Pi OS automation configured${NC}"
}

# Main function (similar structure to DietPi version)
main() {
    echo -e "${GREEN}Raspberry Pi OS Automated Setup Tool${NC}"
    echo "====================================="
    echo "With Wayland support for 4K displays"
    echo

    # Check if no arguments provided
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: No arguments provided${NC}"
        echo
        echo "This script requires several arguments to configure your Raspberry Pi."
        echo "Run with --help for usage information."
        exit 1
    fi

    # Check and install required tools
    check_and_install_tools

    # Parse arguments - no defaults, all required
    local url=""
    local wifi_ssid=""
    local wifi_password=""
    local wifi_enterprise_user=""
    local wifi_enterprise_pass=""
    local hostname=""
    local username=""
    local password=""
    local tailscale_authkey=""
    local ssh_key_file="$HOME/.ssh/panic_rpi_ssh.pub"

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
            --list-cache)
                echo -e "${GREEN}Cached Raspberry Pi OS images:${NC}"
                if [ -d "$CACHE_DIR" ] && [ "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]; then
                    ls -lh "$CACHE_DIR" | grep -v "^total" | while read line; do
                        echo "  $line"
                    done
                else
                    echo "  No cached images found"
                fi
                echo -e "\nCache directory: $CACHE_DIR"
                exit 0
                ;;
            --clear-cache)
                if [ -d "$CACHE_DIR" ]; then
                    echo -e "${YELLOW}Clearing image cache...${NC}"
                    rm -rf "$CACHE_DIR"/*
                    echo -e "${GREEN}✓ Cache cleared${NC}"
                else
                    echo -e "${YELLOW}No cache directory found${NC}"
                fi
                exit 0
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Required Options:
    --url <url>                  URL to display in kiosk mode
    --hostname <name>            Hostname for the Raspberry Pi
    --username <user>            Username for the admin account
    --password <pass>            Password for the admin account

Network Options (at least one required):
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK networks)
    --wifi-enterprise-user <u>   Enterprise WiFi username (use with --wifi-ssid)
    --wifi-enterprise-pass <p>   Enterprise WiFi password (use with --wifi-ssid)

Optional:
    --tailscale-authkey <key>    Tailscale auth key for automatic join
    --ssh-key <path>             Path to SSH public key (default: ~/.ssh/panic_rpi_ssh.pub)

Utility Commands:
    --list-cache                 List cached images
    --clear-cache                Clear all cached images
    --help                       Show this help message

Examples:
    # Regular WiFi:
    $0 --url "https://example.com" \\
       --hostname "kiosk-pi" \\
       --username "admin" \\
       --password "securepass123" \\
       --wifi-ssid "MyNetwork" \\
       --wifi-password "MyPassword"

    # Enterprise WiFi:
    $0 --url "https://example.com" \\
       --hostname "kiosk-display" \\
       --username "admin" \\
       --password "securepass123" \\
       --wifi-ssid "CorpNetwork" \\
       --wifi-enterprise-user "username@domain.com" \\
       --wifi-enterprise-pass "password"

    # With Tailscale for remote access:
    $0 --url "https://panic.fly.dev" \\
       --hostname "panic-display-1" \\
       --username "panic" \\
       --password "mypassword" \\
       --wifi-ssid "HomeWiFi" \\
       --wifi-password "wifipass" \\
       --tailscale-authkey "tskey-auth-..."

    # With SSH key for passwordless access:
    $0 --url "https://example.com" \\
       --hostname "kiosk-display" \\
       --username "admin" \\
       --password "securepass123" \\
       --wifi-ssid "MyNetwork" \\
       --wifi-password "MyPassword" \\
       --ssh-key ~/.ssh/id_rsa.pub

Features:
    - Full 4K display support via Wayland
    - Automatic resolution detection
    - Chromium kiosk mode with GPU acceleration
    - Tailscale SSH access
    - WiFi configuration (WPA2 and Enterprise)

After setup with Tailscale, you can SSH to the Pi using:
    ssh $username@<hostname>  (using Tailscale hostname)

Cache Management:
    Images are cached in: $CACHE_DIR
    Cached images expire after 30 days and are automatically re-downloaded
EOF
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    local missing_args=()

    if [ -z "$url" ]; then
        missing_args+=("--url")
    fi

    if [ -z "$hostname" ]; then
        missing_args+=("--hostname")
    fi

    if [ -z "$username" ]; then
        missing_args+=("--username")
    fi

    if [ -z "$password" ]; then
        missing_args+=("--password")
    fi

    # WiFi requires either regular password OR enterprise credentials
    if [ -n "$wifi_ssid" ]; then
        if [ -z "$wifi_password" ] && ([ -z "$wifi_enterprise_user" ] || [ -z "$wifi_enterprise_pass" ]); then
            echo -e "${RED}Error: WiFi SSID provided but no credentials${NC}"
            echo "Either provide --wifi-password for regular WiFi"
            echo "Or provide both --wifi-enterprise-user and --wifi-enterprise-pass for enterprise WiFi"
            exit 1
        fi
    fi

    # Check if any required arguments are missing
    if [ ${#missing_args[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required arguments: ${missing_args[*]}${NC}"
        echo
        echo "Required arguments:"
        echo "  --url <url>          The URL to display in kiosk mode"
        echo "  --hostname <name>    Hostname for the Raspberry Pi"
        echo "  --username <user>    Username for the admin account"
        echo "  --password <pass>    Password for the admin account"
        echo
        echo "Optional arguments:"
        echo "  --wifi-ssid <ssid>   WiFi network name (optional if using ethernet)"
        echo "  --wifi-password      WiFi password (for WPA2-PSK networks)"
        echo "  --wifi-enterprise-*  Enterprise WiFi credentials"
        echo "  --tailscale-authkey  Tailscale auth key for remote access"
        echo
        echo "Run with --help for full usage information"
        exit 1
    fi

    # Find SD card
    sd_device=$(find_sd_card)
    if [ -z "$sd_device" ]; then
        exit 1
    fi

    echo -e "${GREEN}Using SD card: $sd_device${NC}"

    # Confirm with user
    echo -e "${YELLOW}WARNING: This will erase all data on $sd_device${NC}"
    echo -n "Continue? (yes/no): "
    read -r response
    if [ "$response" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi

    # Download Raspberry Pi OS image
    local temp_image="/tmp/raspi_os_image.img.xz"
    download_raspi_os "$temp_image"

    # Write image to SD card
    write_image_to_sd "$temp_image" "$sd_device"

    # Wait for device to settle after write
    echo "Waiting for device to settle..."
    sleep 3

    # Force mount the disk
    echo "Mounting partitions..."
    diskutil mountDisk "$sd_device" || true
    sleep 2

    # Find boot partition - Raspberry Pi OS uses bootfs
    local boot_mount=""

    # First try common mount points
    for mount in /Volumes/bootfs /Volumes/boot /Volumes/BOOT /Volumes/NO\ NAME; do
        if [ -d "$mount" ]; then
            # Check if it looks like a boot partition
            if [ -f "$mount/config.txt" ] || [ -f "$mount/cmdline.txt" ]; then
                boot_mount="$mount"
                echo -e "${GREEN}✓ Found boot partition at: $boot_mount${NC}"
                break
            fi
        fi
    done

    # If not found, try to find FAT partition
    if [ -z "$boot_mount" ]; then
        echo "Searching for boot partition..."
        # Get the FAT partition (usually s1)
        local fat_partition=$(diskutil list "$sd_device" | grep "DOS_FAT" | awk '{print $NF}')
        if [ -n "$fat_partition" ]; then
            echo "Attempting to mount $fat_partition..."
            diskutil mount "$fat_partition"
            sleep 2

            # Check again
            for mount in /Volumes/*; do
                if [ -d "$mount" ] && [ -f "$mount/config.txt" ]; then
                    boot_mount="$mount"
                    echo -e "${GREEN}✓ Found boot partition at: $boot_mount${NC}"
                    break
                fi
            done
        fi
    fi

    if [ -z "$boot_mount" ]; then
        echo -e "${RED}Error: Boot partition not found${NC}"
        echo "Available volumes:"
        ls -la /Volumes/
        echo ""
        echo "Disk layout:"
        diskutil list "$sd_device"
        exit 1
    fi

    # Configure Raspberry Pi OS
    configure_raspi_os "$boot_mount" "$wifi_ssid" "$wifi_password" \
                      "$wifi_enterprise_user" "$wifi_enterprise_pass" \
                      "$url" "$hostname" "$username" "$password" \
                      "$tailscale_authkey" "$ssh_key_file"

    # Sync and eject SD card
    echo -e "${YELLOW}Syncing and ejecting SD card...${NC}"
    sync
    sleep 2
    diskutil eject "$sd_device"

    echo -e "${GREEN}✓ SD card is ready!${NC}"
    echo
    echo "Next steps:"
    echo "1. Insert the SD card into your Raspberry Pi"
    echo "2. Power on the Pi"
    echo "3. Raspberry Pi OS will automatically:"
    echo "   - Connect to WiFi"
    echo "   - Run first-boot configuration"
    echo "   - Install Chromium and Wayland compositor"
    echo "   - Configure kiosk mode with 4K support"
    echo "   - Reboot into kiosk mode displaying: $url"
    echo
    if [ -n "$tailscale_authkey" ]; then
        echo "Tailscale access:"
        echo "   ssh $username@$hostname  (via Tailscale network)"
        if [ -f "$ssh_key_file" ]; then
            echo "   (Passwordless access via SSH key)"
        fi
        echo "   No need for port forwarding or VPN!"
        echo
    else
        if [ -f "$ssh_key_file" ]; then
            echo "SSH access:"
            echo "   ssh $username@${hostname}.local"
            echo "   (Passwordless access via SSH key)"
            echo
        fi
    fi
    echo "Note: First boot takes 5-10 minutes for automated setup"
    echo
    echo "Features:"
    echo "   - Full 4K display support via Wayland"
    echo "   - Automatic resolution detection"
    echo "   - GPU-accelerated Chromium"
    echo "   - Use 'kiosk-url' command to change URL"
}

# Run main function
main "$@"
