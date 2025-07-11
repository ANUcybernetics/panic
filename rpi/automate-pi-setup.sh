#!/bin/bash
# DietPi automated SD card setup for Raspberry Pi kiosk mode
# This script creates a fully automated DietPi installation that boots directly into Chromium kiosk mode

set -e
set -u
set -o pipefail

# Configuration
readonly DIETPI_IMAGE_URL="https://dietpi.com/downloads/images/DietPi_RPi5-ARMv8-Bookworm.img.xz"
readonly DEFAULT_URL="https://panic.fly.dev"
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

# Function to find SD card device (dynamically finds the built-in SDXC reader)
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
    curl -L -o "$cached_file" "$DIETPI_IMAGE_URL"
    cp "$cached_file" "$output_file"
    echo -e "${GREEN}✓ Image cached for future use${NC}"
}


# Function to write image to SD card
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
        # Get uncompressed size for progress bar (remove commas from the number)
        local uncompressed_size=$(xz -l "$image_file" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d ',')
        
        # Fallback to known sizes if xz -l fails
        if [ -z "$uncompressed_size" ] || [ "$uncompressed_size" -eq 0 ] 2>/dev/null; then
            # Try to determine size based on filename
            case "$image_file" in
                *DietPi*RPi5*Bookworm*)
                    # DietPi RPi5 Bookworm is approximately 2.1GB uncompressed
                    uncompressed_size=$((2100 * 1024 * 1024))
                    echo "Using known size for DietPi RPi5 Bookworm..."
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
AUTO_SETUP_NET_WIFI_COUNTRY_CODE=AU

##### Software Options #####
# Automated installation
AUTO_SETUP_AUTOMATED=1

# Global password for dietpi user
AUTO_SETUP_GLOBAL_PASSWORD=$password

# Software to install (105 = OpenSSH Server, 113 = Chromium)
# Note: Don't include desktop environments as they conflict with kiosk mode
AUTO_SETUP_INSTALL_SOFTWARE_ID=105,113

# Enable auto-login
AUTO_SETUP_AUTOSTART_TARGET_INDEX=11
AUTO_SETUP_AUTOSTART_LOGIN_USER=dietpi

# Disable serial console
AUTO_SETUP_SERIAL_CONSOLE_ENABLE=0

# Locale
AUTO_SETUP_LOCALE=en_AU.UTF-8

# Keyboard
AUTO_SETUP_KEYBOARD_LAYOUT=us

# Timezone
AUTO_SETUP_TIMEZONE=Australia/Sydney

##### DietPi-Config Settings #####
# Disable swap
CONFIG_SWAP_SIZE=0

# GPU memory split (256MB for better 4K support)
CONFIG_GPU_MEM_SPLIT=256

# Disable Bluetooth
CONFIG_BLUETOOTH_DISABLE=1

# Disable IPv6
CONFIG_ENABLE_IPV6=0

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
    
    # Create custom automation script for kiosk setup
    cat > "$boot_mount/Automation_Custom_Script.sh" << 'CUSTOM_SCRIPT'
#!/bin/bash
# DietPi custom automation script for kiosk mode

# Wait for network
echo "Waiting for network connectivity..."
while ! ping -c 1 google.com > /dev/null 2>&1; do
    sleep 2
done

# Install and configure Tailscale if auth key provided
# Check both possible locations for the auth key
AUTHKEY_PATH=""
if [ -f /boot/firmware/dietpi_userdata/tailscale_authkey ]; then
    AUTHKEY_PATH="/boot/firmware/dietpi_userdata/tailscale_authkey"
elif [ -f /boot/dietpi_userdata/tailscale_authkey ]; then
    AUTHKEY_PATH="/boot/dietpi_userdata/tailscale_authkey"
fi

if [ -n "$AUTHKEY_PATH" ]; then
    echo "Installing Tailscale..."
    
    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Read the auth key
    TAILSCALE_AUTHKEY=$(cat "$AUTHKEY_PATH")
    
    # Start tailscale and authenticate
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --hostname="HOSTNAME_PLACEHOLDER"
    
    # Enable SSH access via Tailscale
    echo "Tailscale installed and connected"
    
    # Remove the auth key file for security
    rm -f "$AUTHKEY_PATH"
fi

# Install required packages for kiosk mode
echo "Installing required packages..."
apt-get update
apt-get install -y unclutter-xfixes openbox

# Note: openbox is needed because DietPi's kiosk mode doesn't include a window manager
# Without it, X sessions fail with "no window managers found"

# Backup original chromium autostart script
if [ -f /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh ]; then
    cp /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh \
       /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh.orig
fi

# Create enhanced chromium autostart script with all our improvements
cat > /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh << 'EOF'
#!/bin/dash
# Enhanced autostart script for kiosk mode with auto-resolution detection

# Hide mouse cursor using multiple methods for reliability
# Method 1: unclutter-xfixes (most reliable)
unclutter --hide-on-touch --start-hidden --timeout 0 &

# Method 2: Set cursor to invisible theme as backup
xsetroot -cursor_name none 2>/dev/null || true

# Find dietpi.txt location
DIETPI_TXT="/boot/dietpi.txt"
[ -f "/boot/firmware/dietpi.txt" ] && DIETPI_TXT="/boot/firmware/dietpi.txt"

# Resolution to use for kiosk mode
RES_X=$(sed -n '/^[[:blank:]]*SOFTWARE_CHROMIUM_RES_X=/{s/^[^=]*=//p;q}' "$DIETPI_TXT")
RES_Y=$(sed -n '/^[[:blank:]]*SOFTWARE_CHROMIUM_RES_Y=/{s/^[^=]*=//p;q}' "$DIETPI_TXT")

# If resolution not set or set to 0, try to auto-detect
if [ -z "$RES_X" ] || [ -z "$RES_Y" ] || [ "$RES_X" = "0" ] || [ "$RES_Y" = "0" ]; then
    # Wait longer for display to be ready (especially for 4K displays)
    sleep 5
    
    # Export DISPLAY if not set
    export DISPLAY=:0
    
    # Try to get resolution from xrandr with multiple attempts
    for attempt in 1 2 3; do
        if command -v xrandr >/dev/null 2>&1; then
            # Get the primary display or first connected display
            RESOLUTION=$(xrandr 2>/dev/null | grep ' connected' | head -1 | grep -oE '[0-9]+x[0-9]+' | head -1)
            if [ -n "$RESOLUTION" ]; then
                RES_X=$(echo "$RESOLUTION" | cut -d'x' -f1)
                RES_Y=$(echo "$RESOLUTION" | cut -d'x' -f2)
                echo "Auto-detected resolution (attempt $attempt): ${RES_X}x${RES_Y}"
                break
            fi
        fi
        # Wait before retry
        sleep 2
    done
fi

# Default to 1920x1080 if still not set
RES_X=${RES_X:-1920}
RES_Y=${RES_Y:-1080}

# Log the resolution being used
echo "Using resolution: ${RES_X}x${RES_Y}" | tee /var/log/chromium-kiosk.log

# Command line switches with comprehensive kiosk flags
CHROMIUM_OPTS="--kiosk --window-size=${RES_X},${RES_Y} --window-position=0,0"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-infobars --disable-session-crashed-bubble"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-features=TranslateUI"
CHROMIUM_OPTS="$CHROMIUM_OPTS --check-for-update-interval=31536000"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-component-update"
CHROMIUM_OPTS="$CHROMIUM_OPTS --autoplay-policy=no-user-gesture-required"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-features=OverscrollHistoryNavigation"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-pinch"
CHROMIUM_OPTS="$CHROMIUM_OPTS --noerrdialogs"
CHROMIUM_OPTS="$CHROMIUM_OPTS --no-first-run"
CHROMIUM_OPTS="$CHROMIUM_OPTS --fast --fast-start"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-features=Translate"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disk-cache-dir=/tmp/chromium-cache"
CHROMIUM_OPTS="$CHROMIUM_OPTS --enable-features=OverlayScrollbar"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-touch-drag-drop"

# Additional flags for better 4K/high-res display support
CHROMIUM_OPTS="$CHROMIUM_OPTS --force-device-scale-factor=1"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-gpu-vsync"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-smooth-scrolling"
CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-features=UseModernMediaControls"
CHROMIUM_OPTS="$CHROMIUM_OPTS --enable-gpu-rasterization"
CHROMIUM_OPTS="$CHROMIUM_OPTS --enable-accelerated-2d-canvas"

# For 4K displays, disable GPU to avoid DMA buffer errors
if [ "$RES_X" -gt 2560 ] || [ "$RES_Y" -gt 1440 ]; then
    echo "Detected high resolution display, applying optimizations..."
    CHROMIUM_OPTS="$CHROMIUM_OPTS --max-old-space-size=4096"
    CHROMIUM_OPTS="$CHROMIUM_OPTS --memory-pressure-off"
    # Disable GPU for 4K displays to avoid rendering issues
    CHROMIUM_OPTS="$CHROMIUM_OPTS --disable-gpu --disable-gpu-compositing"
    echo "GPU disabled for 4K display compatibility"
fi

# Home page URL
URL=$(sed -n '/^[[:blank:]]*SOFTWARE_CHROMIUM_AUTOSTART_URL=/{s/^[^=]*=//p;q}' "$DIETPI_TXT")

# RPi or Debian Chromium package
FP_CHROMIUM=$(command -v chromium-browser)
[ "$FP_CHROMIUM" ] || FP_CHROMIUM=$(command -v chromium)

# Use "startx" as non-root user to get required permissions
STARTX='xinit'
[ "$USER" = 'root' ] || STARTX='startx'

# Create a temporary xinitrc to ensure cursor hiding and screen settings
XINITRC_TMP="/tmp/chromium-xinitrc-$$"
cat > "$XINITRC_TMP" << XINITRC_EOF
#!/bin/sh
# Disable screen blanking and power management
xset -dpms
xset s off
xset s noblank

# Hide cursor multiple ways
xsetroot -cursor_name none
unclutter --hide-on-touch --start-hidden --timeout 0 &

# For high-resolution displays, ensure proper mode is set
if command -v xrandr >/dev/null 2>&1; then
    # Get the connected display
    DISPLAY_OUTPUT=\$(xrandr | grep ' connected' | head -1 | awk '{print \$1}')
    
    # Check if 4K resolution is detected
    if xrandr | grep -q "3840x2160\\|4096x2160"; then
        echo "4K display detected, attempting to set mode..."
        # Try 4K first, but be prepared to fall back
        if ! xrandr --output \$DISPLAY_OUTPUT --mode 3840x2160 --rate 30 2>/dev/null; then
            echo "4K mode failed, falling back to 1080p..."
            xrandr --output \$DISPLAY_OUTPUT --mode 1920x1080 --rate 60 2>/dev/null || true
        fi
    else
        # Non-4K display, use best available mode
        BEST_MODE=\$(xrandr 2>/dev/null | grep -A1 ' connected' | tail -1 | awk '{print \$1}')
        if [ -n "\$BEST_MODE" ]; then
            echo "Setting display mode to: \$BEST_MODE"
            xrandr --output \$DISPLAY_OUTPUT --mode \$BEST_MODE --rate 60 2>/dev/null || true
        fi
    fi
fi

# Start openbox window manager in background
openbox &
sleep 1

# Small delay to ensure display is ready
sleep 1

# Launch Chromium
exec "$FP_CHROMIUM" $CHROMIUM_OPTS "${URL:-https://dietpi.com/}"
XINITRC_EOF
chmod +x "$XINITRC_TMP"

# Start X with our custom xinitrc
XINITRC="$XINITRC_TMP" exec "$STARTX"
EOF

# Make the script executable
chmod +x /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh

# Create the kiosk-url helper script
cat > /usr/local/bin/kiosk-url << 'EOF'
#!/bin/bash
# Simple script to change the kiosk URL

# Find dietpi.txt location
DIETPI_TXT="/boot/dietpi.txt"
[ -f "/boot/firmware/dietpi.txt" ] && DIETPI_TXT="/boot/firmware/dietpi.txt"

if [ $# -eq 0 ]; then
    echo "Current kiosk URL:"
    grep "^SOFTWARE_CHROMIUM_AUTOSTART_URL=" "$DIETPI_TXT" | cut -d= -f2
    echo ""
    echo "Usage: kiosk-url <new-url>"
    echo "Example: kiosk-url https://example.com"
    exit 0
fi

NEW_URL="$1"

# Update the URL in dietpi.txt
sudo sed -i "s|^SOFTWARE_CHROMIUM_AUTOSTART_URL=.*|SOFTWARE_CHROMIUM_AUTOSTART_URL=$NEW_URL|" "$DIETPI_TXT"

echo "Kiosk URL changed to: $NEW_URL"
echo "Restarting kiosk..."

# Restart the display
sudo systemctl restart getty@tty1

echo "Done! The kiosk should now display: $NEW_URL"
EOF

chmod +x /usr/local/bin/kiosk-url

echo "Kiosk setup complete with enhanced features"
CUSTOM_SCRIPT
    
    # Replace placeholders in the script (handle spaces in path)
    # macOS sed doesn't handle -i well with spaces in paths, so use a temp file
    sed "s|HOSTNAME_PLACEHOLDER|$hostname|g" "$boot_mount/Automation_Custom_Script.sh" > "$boot_mount/Automation_Custom_Script.sh.tmp"
    mv "$boot_mount/Automation_Custom_Script.sh.tmp" "$boot_mount/Automation_Custom_Script.sh"
    
    chmod +x "$boot_mount/Automation_Custom_Script.sh"
    
    echo -e "${GREEN}✓ DietPi automation configured${NC}"
}

# Main function
main() {
    echo -e "${GREEN}DietPi Automated Setup Tool${NC}"
    echo "=================================="
    
    # Parse arguments
    local url="$DEFAULT_URL"
    local wifi_ssid=""
    local wifi_password=""
    local wifi_enterprise_user=""
    local wifi_enterprise_pass=""
    local hostname="DietPi"
    local username="dietpi"
    local password="dietpi"
    local tailscale_authkey=""
    
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
            --list-cache)
                echo -e "${GREEN}Cached DietPi images:${NC}"
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

Options:
    --url <url>                  Kiosk URL (default: $DEFAULT_URL)
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK)
    --wifi-enterprise-user <u>   Enterprise WiFi username
    --wifi-enterprise-pass <p>   Enterprise WiFi password
    --hostname <name>            Custom hostname (default: DietPi)
    --username <user>            Username (default: dietpi)
    --password <pass>            Password (default: dietpi)
    --tailscale-authkey <key>    Tailscale auth key for automatic join
    --list-cache                 List cached DietPi images
    --clear-cache                Clear all cached images
    --help                       Show this help message

Examples:
    # Regular WiFi:
    $0 --url "https://example.com" --wifi-ssid "MyNetwork" --wifi-password "MyPassword"
    
    # Enterprise WiFi:
    $0 --url "https://example.com" --wifi-ssid "CorpNetwork" \\
       --wifi-enterprise-user "username@domain.com" \\
       --wifi-enterprise-pass "password" \\
       --hostname "kiosk-display"

After setup with Tailscale, you can SSH to the Pi using:
    ssh dietpi@<hostname>  (using Tailscale hostname)

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
    
    # Download DietPi image
    local temp_image="/tmp/dietpi_image.img.xz"
    download_dietpi "$temp_image"
    
    # Write image to SD card
    write_image_to_sd "$temp_image" "$sd_device"
    
    # Wait for device to settle after write
    echo "Waiting for device to settle..."
    sleep 3
    
    # Force mount the disk
    echo "Mounting partitions..."
    diskutil mountDisk "$sd_device" || true
    sleep 2
    
    # Find boot partition - DietPi uses FAT partition
    local boot_mount=""
    
    # First try common mount points
    for mount in /Volumes/bootfs /Volumes/boot /Volumes/BOOT /Volumes/NO\ NAME; do
        if [ -d "$mount" ]; then
            # Check if it looks like a boot partition (has dietpi.txt or config.txt)
            if [ -f "$mount/config.txt" ] || [ -f "$mount/dietpi.txt" ] || [ -d "$mount/dietpi" ]; then
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
                if [ -d "$mount" ] && ([ -f "$mount/config.txt" ] || [ -f "$mount/dietpi.txt" ] || [ -d "$mount/dietpi" ]); then
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
    
    # Configure DietPi
    configure_dietpi "$boot_mount" "$wifi_ssid" "$wifi_password" \
                    "$wifi_enterprise_user" "$wifi_enterprise_pass" \
                    "$url" "$hostname" "$username" "$password" \
                    "$tailscale_authkey"
    
    
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
    echo "3. DietPi will automatically:"
    echo "   - Connect to WiFi"
    echo "   - Install minimal desktop and Chromium"
    echo "   - Configure kiosk mode"
    echo "   - Reboot into kiosk mode displaying: $url"
    echo
    if [ -n "$tailscale_authkey" ]; then
        echo
        echo "Tailscale access:"
        echo "   ssh dietpi@$hostname  (via Tailscale network)"
        echo "   No need for port forwarding or VPN!"
    fi
    echo
    echo "Note: First boot takes 5-10 minutes for automated setup"
}

# Run main function
main "$@"