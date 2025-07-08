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
readonly SSH_KEY_PATH="$HOME/.ssh/panic_rpi_ssh"

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

# Function to find SD card device (hardcoded to /dev/disk4 for your Mac)
find_sd_card() {
    echo -e "${YELLOW}Checking for SD card in built-in reader...${NC}" >&2
    
    # Check if /dev/disk4 exists and is the SD card reader
    if [ -e "/dev/disk4" ]; then
        # Verify it's the built-in SDXC reader
        local device_info=$(diskutil info /dev/disk4 2>/dev/null | grep "Device / Media Name:")
        if echo "$device_info" | grep -q "Built In SDXC Reader"; then
            # Check if it's removable media (i.e., has an SD card inserted)
            if diskutil info /dev/disk4 2>/dev/null | grep -q "Removable Media:.*Removable"; then
                echo -e "${GREEN}✓ Found SD card in built-in reader${NC}" >&2
                echo "/dev/disk4"
                return 0
            else
                echo -e "${RED}Error: Built-in SD card reader found but no SD card inserted${NC}" >&2
                echo -e "${YELLOW}Please insert an SD card and run the script again${NC}" >&2
                return 1
            fi
        else
            echo -e "${RED}Error: /dev/disk4 exists but is not the built-in SD card reader${NC}" >&2
            echo -e "${YELLOW}Found: $device_info${NC}" >&2
            return 1
        fi
    else
        echo -e "${RED}Error: /dev/disk4 not found${NC}" >&2
        echo -e "${YELLOW}This script expects the built-in SD card reader to be at /dev/disk4${NC}" >&2
        return 1
    fi
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

# Function to generate or use SSH key
setup_ssh_key() {
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo -e "${YELLOW}Generating SSH key for Raspberry Pi access...${NC}" >&2
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "panic-rpi-access"
        echo -e "${GREEN}✓ SSH key generated at $SSH_KEY_PATH${NC}" >&2
    else
        echo -e "${GREEN}✓ Using existing SSH key at $SSH_KEY_PATH${NC}" >&2
    fi
    
    # Get the public key
    if [ -f "${SSH_KEY_PATH}.pub" ]; then
        cat "${SSH_KEY_PATH}.pub"
    else
        echo -e "${RED}Error: Public key not found at ${SSH_KEY_PATH}.pub${NC}" >&2
        exit 1
    fi
}

# Function to write image to SD card
write_image_to_sd() {
    local image_file="$1"
    local device="$2"
    
    echo -e "${YELLOW}Writing image to SD card...${NC}"
    echo "This will take several minutes..."
    
    # Unmount any mounted partitions
    diskutil unmountDisk force "$device" || true
    
    # Decompress and write in one step
    echo "Decompressing and writing image..."
    xzcat "$image_file" | sudo dd of="$device" bs=4m
    
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
    local ssh_pubkey="${10}"
    
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

# Software to install (113 = Chromium, 173 = LXDE desktop)
AUTO_SETUP_INSTALL_SOFTWARE_ID=173,113

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

# GPU memory split
CONFIG_GPU_MEM_SPLIT=128

# Disable Bluetooth
CONFIG_BLUETOOTH_DISABLE=1

# Disable IPv6
CONFIG_ENABLE_IPV6=0

# Custom script to run after installation
AUTO_SETUP_CUSTOM_SCRIPT_EXEC=/boot/Automation_Custom_Script.sh
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
    
    # Add SSH key
    mkdir -p "$boot_mount/dietpi_userdata"
    echo "$ssh_pubkey" > "$boot_mount/dietpi_userdata/ssh_pubkey"
    
    # Create custom automation script for kiosk setup
    cat > "$boot_mount/Automation_Custom_Script.sh" << CUSTOM_SCRIPT
#!/bin/bash
# DietPi custom automation script for kiosk mode

# Set the kiosk URL
KIOSK_URL="$url"

# Wait for network
while ! ping -c 1 google.com > /dev/null 2>&1; do
    sleep 2
done

# Install SSH key
if [ -f /boot/dietpi_userdata/ssh_pubkey ]; then
    mkdir -p /home/dietpi/.ssh
    cat /boot/dietpi_userdata/ssh_pubkey >> /home/dietpi/.ssh/authorized_keys
    chmod 700 /home/dietpi/.ssh
    chmod 600 /home/dietpi/.ssh/authorized_keys
    chown -R dietpi:dietpi /home/dietpi/.ssh
fi

# Configure Chromium for kiosk mode
mkdir -p /home/dietpi/.config/openbox
cat > /home/dietpi/.config/openbox/autostart << EOF
# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Hide mouse cursor after 0.5 seconds of inactivity
unclutter -idle 0.5 &

# Start Chromium in kiosk mode with explicit URL
chromium --kiosk --noerrdialogs --disable-infobars --no-first-run --fast --fast-start --disable-features=TranslateUI --disk-cache-dir=/tmp/chromium-cache --disable-pinch --overscroll-history-navigation=disabled --disable-features=OverscrollHistoryNavigation "\$KIOSK_URL" &
EOF

# Set permissions
chown -R dietpi:dietpi /home/dietpi/.config

# Enable auto-login for LXDE
/boot/dietpi/dietpi-autostart 11

echo "Kiosk setup complete with URL: \$KIOSK_URL"
CUSTOM_SCRIPT
    
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

After setup, you can SSH to the Pi using:
    ssh -i ~/.ssh/panic_rpi_ssh dietpi@<hostname>.local

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
    
    # Setup SSH key
    local ssh_pubkey=$(setup_ssh_key)
    
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
                    "$url" "$hostname" "$username" "$password" "$ssh_pubkey"
    
    # Update SSH config
    if ! grep -q "Host $hostname" ~/.ssh/config 2>/dev/null; then
        echo -e "\n# DietPi Kiosk Pi" >> ~/.ssh/config
        echo "Host $hostname" >> ~/.ssh/config
        echo "    HostName $hostname.local" >> ~/.ssh/config
        echo "    User dietpi" >> ~/.ssh/config
        echo "    IdentityFile $SSH_KEY_PATH" >> ~/.ssh/config
        echo "    StrictHostKeyChecking no" >> ~/.ssh/config
        echo -e "${GREEN}✓ SSH config updated${NC}"
    fi
    
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
    echo "SSH access (after ~5-10 minutes for initial setup):"
    echo "   ssh $hostname"
    echo
    echo "Note: First boot takes 5-10 minutes for automated setup"
}

# Run main function
main "$@"