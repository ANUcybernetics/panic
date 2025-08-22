#!/bin/bash
# Raspberry Pi OS Bookworm automated SD card setup for Raspberry Pi 5 kiosk mode
# This script creates a fully automated Raspberry Pi OS installation that boots directly into 
# GPU-accelerated Chromium kiosk mode using Wayland/labwc and automatically joins Tailscale
#
# Features:
# - Full GPU acceleration with labwc Wayland compositor (RPi OS default)
# - Native 4K display support with auto-detection
# - Consumer and enterprise WiFi configuration
# - Automatic Tailscale network join
# - Optimized for Raspberry Pi 5 with 8GB RAM
# - Uses official Raspberry Pi OS Bookworm
# - Uses SDM (https://github.com/gitbls/sdm) for reliable image customization
#
# Uses latest Raspberry Pi OS Bookworm (64-bit)

set -e
set -u
set -o pipefail

# Configuration
readonly RASPIOS_IMAGE_URL="https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64.img.xz"
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
    for cmd in curl xz dd mktemp jq git; do
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

# Check for SDM installation
check_sdm() {
    echo -e "${YELLOW}Checking for SDM installation...${NC}"
    
    if ! command -v sdm >/dev/null 2>&1; then
        echo -e "${RED}Error: SDM is not installed${NC}"
        echo ""
        echo "Please install SDM first by running:"
        echo "  ./install-sdm.sh"
        echo ""
        echo "Or manually install from: https://github.com/gitbls/sdm"
        exit 1
    else
        echo -e "${GREEN}✓ SDM is installed${NC}"
    fi
}

# Function to find SD card device
find_sd_card() {
    echo -e "${YELLOW}Looking for SD card devices...${NC}" >&2
    
    # List removable block devices
    local devices=()
    local device_info=()
    
    while IFS= read -r line; do
        local device="/dev/$line"
        local removable=$(cat "/sys/block/$line/removable" 2>/dev/null || echo "0")
        local size=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1 || echo "0")
        local size_gb=$((size / 1024 / 1024 / 1024))
        
        # Get model info
        local model=$(lsblk -n -o MODEL "$device" 2>/dev/null | head -1 | tr -d ' ' || echo "Unknown")
        
        # Include removable devices between 2GB and 256GB
        if [ "$removable" = "1" ] && [ "$size_gb" -ge 2 ] && [ "$size_gb" -le 256 ]; then
            devices+=("$device")
            device_info+=("${size_gb}GB - $model")
        fi
    done < <(ls /sys/block/ | grep -E '^(sd|mmcblk)[a-z0-9]*$')
    
    if [ ${#devices[@]} -eq 0 ]; then
        echo -e "${RED}Error: No SD card devices found${NC}" >&2
        echo -e "${YELLOW}Please insert an SD card and run the script again${NC}" >&2
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
        echo "  $((i+1))) ${devices[$i]} - ${device_info[$i]}" >&2
    done
    
    echo -n "Select device (1-${#devices[@]}): " >&2
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#devices[@]} ]; then
        echo -e "${GREEN}✓ Selected ${devices[$((selection-1))]} (${device_info[$((selection-1))]})${NC}" >&2
        echo "${devices[$((selection-1))]}"
        return 0
    else
        echo -e "${RED}Error: Invalid selection${NC}" >&2
        return 1
    fi
}

# Function to download and prepare Raspberry Pi OS image
prepare_raspios_image() {
    local work_dir="$1"

    # Create cache directory if it doesn't exist
    mkdir -p "$CACHE_DIR"

    # Extract filename from URL
    local filename=$(basename "$RASPIOS_IMAGE_URL")
    local cached_compressed="$CACHE_DIR/$filename"
    local cached_img="${cached_compressed%.xz}"
    local work_img="$work_dir/raspios.img"

    # Check if we have a cached uncompressed image
    if [ -f "$cached_img" ]; then
        echo -e "${GREEN}✓ Using cached image: $(basename "$cached_img")${NC}" >&2
        cp "$cached_img" "$work_img"
        echo "$work_img"
        return 0
    fi

    # Check if we have cached compressed version
    if [ -f "$cached_compressed" ]; then
        echo -e "${GREEN}✓ Found cached compressed image${NC}" >&2
    else
        echo -e "${YELLOW}Downloading Raspberry Pi OS image...${NC}" >&2
        if ! curl -L -o "$cached_compressed" "$RASPIOS_IMAGE_URL"; then
            echo -e "${RED}Error: Failed to download image from $RASPIOS_IMAGE_URL${NC}" >&2
            rm -f "$cached_compressed"
            exit 1
        fi
    fi

    # Verify it's actually an xz file
    if ! file "$cached_compressed" | grep -q "XZ compressed data"; then
        echo -e "${RED}Error: Downloaded file is not a valid XZ compressed image${NC}" >&2
        echo "File type: $(file "$cached_compressed")" >&2
        rm -f "$cached_compressed"
        exit 1
    fi

    # Decompress to cache
    echo -e "${YELLOW}Decompressing image...${NC}" >&2
    xz -d -k -c "$cached_compressed" > "$cached_img"
    
    # Copy to work directory
    cp "$cached_img" "$work_img"
    echo -e "${GREEN}✓ Image ready for customization${NC}" >&2
    echo "$work_img"
}

# Function to write image to SD card using SDM
write_image_to_sd() {
    local image_file="$1"
    local device="$2"
    local test_mode="${3:-false}"

    echo -e "${YELLOW}Writing customized image to SD card...${NC}"
    echo "This will take several minutes..."

    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Skipping actual image write${NC}"
        echo "Would write: $image_file -> $device"
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

    echo "Writing image to SD card..."
    
    # Write with built-in dd progress display
    sudo dd if="$image_file" of="$device" bs=4M status=progress oflag=direct

    # Ensure all data is written
    sudo sync

    echo -e "${GREEN}✓ Image written to SD card${NC}"
    
    # Force kernel to re-read partition table
    sudo partprobe "$device" || true
    sleep 2
}

# Create SDM customization script
create_sdm_customization() {
    local work_dir="$1"
    local url="$2"
    local hostname="$3"
    local username="$4"
    local password="$5"
    local wifi_ssid="$6"
    local wifi_password="$7"
    local wifi_enterprise_user="$8"
    local wifi_enterprise_pass="$9"
    local tailscale_authkey="${10}"
    local ssh_key_file="${11}"
    
    echo -e "${YELLOW}Creating SDM customization scripts...${NC}"
    
    # Create plugin directory
    local plugin_dir="$work_dir/plugins"
    mkdir -p "$plugin_dir"
    
    # Create the kiosk setup script that will run at first boot
    cat > "$plugin_dir/kiosk-setup.sh" << 'KIOSK_SCRIPT'
#!/bin/bash
# Kiosk Setup Script - runs at first boot
# This configures the system for kiosk mode

# Don't exit on error - we want to complete as much as possible
set +e

echo "Starting Kiosk Setup at first boot..."
exec 2>&1  # Redirect stderr to stdout for logging

# Read configuration from files
if [ -f /usr/local/sdm/kiosk-config ]; then
    source /usr/local/sdm/kiosk-config
fi

# Set defaults if not provided
KIOSK_URL="${KIOSK_URL:-https://panic.fly.dev/}"
KIOSK_HOSTNAME="${KIOSK_HOSTNAME:-panic-rpi}"
KIOSK_USERNAME="${KIOSK_USERNAME:-panic}"

# Add user to required groups
echo "Adding user to required groups..."
usermod -a -G video,render,input,audio,tty "$KIOSK_USERNAME" || true

# Note: Modern Raspberry Pi OS handles GPU permissions automatically via udev rules

# Configure labwc for kiosk mode (Raspberry Pi OS default compositor)
echo "Configuring labwc..."
USER_HOME="/home/$KIOSK_USERNAME"

# Create labwc config directory
mkdir -p "$USER_HOME/.config/labwc"

# Create labwc autostart for kiosk
cat > "$USER_HOME/.config/labwc/autostart" << 'EOF'
# Hide cursor - unclutter doesn't work with Wayland, so we replace the cursor image
# This makes the cursor invisible system-wide
if [ -f /usr/share/icons/PiXflat/cursors/left_ptr ]; then
    sudo mv /usr/share/icons/PiXflat/cursors/left_ptr /usr/share/icons/PiXflat/cursors/left_ptr.bak
fi

# Start Chromium kiosk via systemd user service
systemctl --user start chromium-kiosk.service &
EOF

chmod +x "$USER_HOME/.config/labwc/autostart"

# Enable the chromium service and timer for the user by creating symlinks
mkdir -p "$USER_HOME/.config/systemd/user/default.target.wants"
mkdir -p "$USER_HOME/.config/systemd/user/timers.target.wants"
ln -sf "../chromium-kiosk.service" "$USER_HOME/.config/systemd/user/default.target.wants/"
ln -sf "../chromium-restart.timer" "$USER_HOME/.config/systemd/user/timers.target.wants/"

# Create minimal labwc config for kiosk mode
cat > "$USER_HOME/.config/labwc/rc.xml" << 'EOF'
<?xml version="1.0"?>
<labwc_config>
  <core>
    <decoration>no</decoration>
    <gap>0</gap>
  </core>
  <keyboard>
    <keybind key="Super-q">
      <action name="Exit"/>
    </keybind>
  </keyboard>
</labwc_config>
EOF

# Create systemd user service for Chromium kiosk
mkdir -p "$USER_HOME/.config/systemd/user"
cat > "$USER_HOME/.config/systemd/user/chromium-kiosk.service" << 'EOF'
[Unit]
Description=Chromium Kiosk Browser
After=graphical-session.target
Requires=graphical-session.target

[Service]
Type=simple
Environment="WAYLAND_DISPLAY=wayland-0"
ExecStartPre=/bin/bash -c 'while [ ! -S "/run/user/$(id -u)/${WAYLAND_DISPLAY}" ]; do sleep 0.5; done'
ExecStart=/bin/bash -c 'BOOT_PARTITION=$([ -d /boot/firmware ] && echo "/boot/firmware" || echo "/boot"); KIOSK_URL=$(cat "$BOOT_PARTITION/kiosk-url.txt" 2>/dev/null || echo "https://panic.fly.dev/"); exec chromium-browser --kiosk --no-first-run --noerrdialogs --disable-infobars --disable-translate --disable-pinch --disable-component-update --autoplay-policy=no-user-gesture-required --check-for-update-interval=31536000 --ozone-platform=wayland "$KIOSK_URL"'
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Create systemd timer to restart chromium at midnight daily
cat > "$USER_HOME/.config/systemd/user/chromium-restart.service" << 'EOF'
[Unit]
Description=Restart Chromium Kiosk Browser
Requires=chromium-kiosk.service

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl --user restart chromium-kiosk.service
EOF

cat > "$USER_HOME/.config/systemd/user/chromium-restart.timer" << 'EOF'
[Unit]
Description=Restart Chromium Kiosk at midnight daily
Requires=chromium-kiosk.service

[Timer]
OnCalendar=daily
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
EOF


# Set ownership
chown -R "$KIOSK_USERNAME:$KIOSK_USERNAME" "$USER_HOME/.config"

# Create a custom labwc session for kiosk mode
cat > /usr/share/wayland-sessions/labwc-kiosk.desktop << EOF
[Desktop Entry]
Name=Labwc Kiosk
Comment=Labwc compositor in kiosk mode
Exec=/usr/local/bin/labwc-kiosk-session.sh
Type=Application
DesktopNames=Labwc
EOF

# Create the session launcher script
cat > /usr/local/bin/labwc-kiosk-session.sh << 'EOF'
#!/bin/bash
# Labwc Kiosk Session Launcher
# This script is executed by LightDM when the user logs in

# Set up environment
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_CLASS=user
export XDG_CURRENT_DESKTOP=Labwc

# Start labwc
exec labwc
EOF

chmod +x /usr/local/bin/labwc-kiosk-session.sh


# Create simple URL management script
cat > /usr/local/bin/kiosk-set-url << 'EOF'
#!/bin/bash
# Script to update the kiosk URL

if [ $# -eq 0 ]; then
    echo "Usage: kiosk-set-url <url>"
    echo "Current URL:"
    BOOT_PARTITION=$([ -d /boot/firmware ] && echo "/boot/firmware" || echo "/boot")
    cat "$BOOT_PARTITION/kiosk-url.txt" 2>/dev/null || echo "Not set"
    exit 1
fi

# Update URL in boot partition
BOOT_PARTITION=$([ -d /boot/firmware ] && echo "/boot/firmware" || echo "/boot")
echo "$1" | sudo tee "$BOOT_PARTITION/kiosk-url.txt" > /dev/null

echo "✓ URL updated. Please reboot for changes to take effect."
EOF

chmod +x /usr/local/bin/kiosk-set-url

# Store URL for persistence  
BOOT_PARTITION=$([ -d /boot/firmware ] && echo "/boot/firmware" || echo "/boot")
echo "$KIOSK_URL" > "$BOOT_PARTITION/kiosk-url.txt"

# No need for custom services - LightDM handles everything!

# Configure the kiosk session
echo "Configuring kiosk session..."

# Autologin is handled by the raspiconfig plugin during customization
# We just need to configure the session to use
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/99-kiosk-session.conf << EOF
[Seat:*]
autologin-session=labwc-kiosk
EOF

# Set the default session for the user
mkdir -p "$USER_HOME/.dmrc"
cat > "$USER_HOME/.dmrc" << EOF
[Desktop]
Session=labwc-kiosk
EOF
chown "$KIOSK_USERNAME:$KIOSK_USERNAME" "$USER_HOME/.dmrc"

# Ensure graphical target is default
systemctl set-default graphical.target

# Enable LightDM
systemctl enable lightdm.service

# Note: Not modifying /boot/firmware/config.txt - using RPi OS defaults

# Handle enterprise WiFi if configured
if [ -n "${WIFI_SSID}" ] && [ -n "${WIFI_ENTERPRISE_USER}" ] && [ -n "${WIFI_ENTERPRISE_PASS}" ]; then
    echo "Configuring enterprise WiFi..."
    
    # Enable WiFi
    rfkill unblock wifi || true
    
    # Configure WiFi country (required for WiFi to work)
    raspi-config nonint do_wifi_country US || true
    
    # Create NetworkManager connection for enterprise WiFi
    cat > "/etc/NetworkManager/system-connections/${WIFI_SSID}.nmconnection" << EOF
[connection]
id=${WIFI_SSID}
uuid=$(uuidgen)
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
mode=infrastructure
ssid=${WIFI_SSID}

[wifi-security]
key-mgmt=wpa-eap

[802-1x]
eap=peap
identity=${WIFI_ENTERPRISE_USER}
password=${WIFI_ENTERPRISE_PASS}
phase2-auth=mschapv2

[ipv4]
method=auto

[ipv6]
method=auto
EOF
    
    chmod 600 "/etc/NetworkManager/system-connections/${WIFI_SSID}.nmconnection"
fi

# Note: Most configuration is done during SDM customization phase
# No need for complex first-boot services since everything is already configured

# Autologin is now configured via the raspiconfig plugin during customization

echo "Kiosk setup plugin completed!"
KIOSK_SCRIPT

    chmod +x "$plugin_dir/kiosk-setup.sh"
    
    # Create configuration file to be copied to the image
    cat > "$plugin_dir/kiosk-config" << EOF
# Kiosk configuration
KIOSK_URL="$url"
KIOSK_HOSTNAME="$hostname"
KIOSK_USERNAME="$username"
WIFI_SSID="$wifi_ssid"
WIFI_PASSWORD="$wifi_password"
WIFI_ENTERPRISE_USER="$wifi_enterprise_user"
WIFI_ENTERPRISE_PASS="$wifi_enterprise_pass"
TAILSCALE_AUTHKEY="$tailscale_authkey"
EOF
    
    # Create Tailscale setup script (runs at first boot)
    if [ -n "$tailscale_authkey" ]; then
        cat > "$plugin_dir/tailscale-setup.sh" << 'TAILSCALE_SCRIPT'
#!/bin/bash
# Tailscale Setup Script - runs at first boot

set -e

echo "Starting Tailscale Setup at first boot..."

# Install Tailscale
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Create systemd service for automatic Tailscale join
cat > /etc/systemd/system/tailscale-join.service << 'EOF'
[Unit]
Description=Join Tailscale Network
After=network-online.target tailscaled.service
Wants=network-online.target
ConditionPathExists=!/var/lib/tailscale/.setup-complete

[Service]
Type=oneshot
EnvironmentFile=/usr/local/sdm/kiosk-config
ExecStartPre=/bin/bash -c 'test -n "${TAILSCALE_AUTHKEY}"'
ExecStart=/usr/bin/tailscale up --authkey=${TAILSCALE_AUTHKEY} --ssh --hostname=${KIOSK_HOSTNAME} --accept-routes --accept-dns=false
ExecStartPost=/bin/mkdir -p /var/lib/tailscale
ExecStartPost=/bin/touch /var/lib/tailscale/.setup-complete
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable tailscale-join.service

echo "Tailscale setup completed!"
TAILSCALE_SCRIPT
        chmod +x "$plugin_dir/tailscale-setup.sh"
    fi
    
    echo -e "${GREEN}✓ SDM customization scripts created${NC}"
}

# Run SDM customization on the image
run_sdm_customization() {
    local work_dir="$1"
    local image_file="$2"
    local url="$3"
    local hostname="$4"
    local username="$5"
    local password="$6"
    local wifi_ssid="$7"
    local wifi_password="$8"
    local wifi_enterprise_user="$9"
    local wifi_enterprise_pass="${10}"
    local tailscale_authkey="${11}"
    local ssh_key_file="${12}"
    local test_mode="${13:-false}"
    
    echo -e "${YELLOW}Running SDM customization...${NC}"
    
    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Skipping SDM customization${NC}"
        echo "Would customize image with:"
        echo "  URL: $url"
        echo "  Hostname: $hostname"
        echo "  Username: $username"
        echo "  WiFi SSID: $wifi_ssid"
        return 0
    fi
    
    # Get localization settings from host system
    local sdm_keymap="us"  # Default to US keyboard
    local sdm_locale="$(locale | grep LANG= | cut -d= -f2 | tr -d '"' || echo 'en_US.UTF-8')"
    local sdm_timezone="$(timedatectl show --property=Timezone --value 2>/dev/null || echo 'UTC')"
    
    echo "Using host locale: $sdm_locale"
    echo "Using host timezone: $sdm_timezone"
    
    # Run SDM customization
    echo -e "${YELLOW}Phase 1: Customizing image...${NC}"
    
    # Build plugin arguments
    local plugin_args=()
    
    # User plugin for creating user account
    plugin_args+=("--plugin" "user:adduser=$username|password=$password")
    
    # Configure boot behavior for graphical desktop with autologin (B4)
    plugin_args+=("--plugin" "raspiconfig:boot_behaviour=B4")
    
    # L10n plugin for localization
    plugin_args+=("--plugin" "L10n:keymap=$sdm_keymap|locale=$sdm_locale|timezone=$sdm_timezone")
    
    # network plugin for WiFi (if regular WiFi)
    if [ -n "$wifi_ssid" ] && [ -z "$wifi_enterprise_user" ]; then
        plugin_args+=("--plugin" "network:wifissid=$wifi_ssid|wifipassword=$wifi_password|wificountry=US")
    fi
    
    # Apps plugin to install required packages (removed unclutter as it doesn't work with Wayland)
    plugin_args+=("--plugin" "apps:apps=jq,curl,uuid-runtime")
    
    # SSH key plugin if provided
    if [ -f "$ssh_key_file" ]; then
        plugin_args+=("--plugin" "sshkey:keyfile=$ssh_key_file|authkeys")
    fi
    
    # runatboot plugin for our custom scripts
    plugin_args+=("--plugin" "runatboot:script=$work_dir/plugins/kiosk-setup.sh|output")
    
    # Add Tailscale setup script if configured
    if [ -n "$tailscale_authkey" ]; then
        plugin_args+=("--plugin" "runatboot:script=$work_dir/plugins/tailscale-setup.sh|output")
    fi
    
    # Copy our plugin scripts and config
    # The copyfile plugin should copy to a file, not create a directory
    # Since /usr/local/sdm is created by SDM, we just need to copy the file there
    plugin_args+=("--plugin" "copyfile:from=$work_dir/plugins/kiosk-config|to=/usr/local/sdm/|chown=root:root")
    
    # Run SDM with all plugins
    sudo sdm \
        --customize \
        --batch \
        --host "$hostname" \
        "${plugin_args[@]}" \
        --plugin disables:piwiz \
        --plugin system:service-enable=ssh,sdm-firstboot \
        --regen-ssh-host-keys \
        --expand-root \
        --restart \
        --apt-options none \
        "$image_file"
    
    echo -e "${GREEN}✓ SDM customization complete${NC}"
}

# Print usage

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Configuration Options:
    --url <url>                  URL to display in kiosk mode (default: https://panic.fly.dev/)
    --hostname <name>            Hostname for the Raspberry Pi (default: panic-rpi)
    --username <user>            Username for the admin account (default: panic)
    --password <pass>            Password for the admin account (default: panic)

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
    local username="panic"
    local password="panic"
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

    # Check for SDM installation
    if [ "$test_mode" != "true" ]; then
        check_sdm
    fi
    
    # Create work directory
    local work_dir=$(mktemp -d -t raspios-setup-XXXXX)
    echo -e "${YELLOW}Using work directory: $work_dir${NC}"
    
    # Prepare Raspberry Pi OS image
    local image_file
    image_file=$(prepare_raspios_image "$work_dir")
    
    # Create SDM customization scripts
    create_sdm_customization "$work_dir" "$url" "$hostname" "$username" \
        "$password" "$wifi_ssid" "$wifi_password" "$wifi_enterprise_user" \
        "$wifi_enterprise_pass" "$tailscale_authkey" "$ssh_key_file"
    
    # Run SDM customization
    run_sdm_customization "$work_dir" "$image_file" "$url" "$hostname" \
        "$username" "$password" "$wifi_ssid" "$wifi_password" \
        "$wifi_enterprise_user" "$wifi_enterprise_pass" "$tailscale_authkey" \
        "$ssh_key_file" "$test_mode"
    
    # Write customized image to SD card
    if [ "$test_mode" != "true" ]; then
        write_image_to_sd "$image_file" "$device" "$test_mode"
    fi

    # Cleanup
    if [ "$test_mode" = "true" ]; then
        echo ""
        echo -e "${YELLOW}TEST MODE: Generated files in: $work_dir${NC}"
        echo "Contents:"
        ls -la "$work_dir/plugins/"
        echo ""
        echo -e "${GREEN}✓ TEST MODE: Configuration test complete!${NC}"
    else
        # Clean up work directory
        rm -rf "$work_dir"
        
        echo -e "${GREEN}✓ SD card ready!${NC}"
        echo -e "${GREEN}You can now safely remove the SD card.${NC}"
    fi

    echo ""
    echo "Next steps:"
    echo "1. Insert the SD card into your Raspberry Pi 5"
    echo "2. Connect Ethernet cable for initial setup (if using WiFi)"
    echo "3. Power on the Pi"
    echo "4. The Pi will boot directly into kiosk mode"
    echo "   - First boot may take a few minutes"
    echo "   - WiFi will connect automatically (if configured)"
    echo "   - Tailscale will join automatically (if configured)"
    echo "   - Kiosk service will start automatically"
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