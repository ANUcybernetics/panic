#!/bin/bash
# Simplified Raspberry Pi OS setup for kiosk mode
# This version uses only proven, reliable methods

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

# Function to find SD card device
find_sd_card() {
    echo -e "${YELLOW}Checking for SD card in built-in reader...${NC}" >&2

    for disk in /dev/disk*; do
        if [[ "$disk" =~ ^/dev/disk[0-9]+$ ]]; then
            local device_info=$(diskutil info "$disk" 2>/dev/null | grep "Device / Media Name:")
            if echo "$device_info" | grep -q "Built In SDXC Reader"; then
                if diskutil info "$disk" 2>/dev/null | grep -q "Removable Media:.*Removable"; then
                    echo -e "${GREEN}✓ Found SD card in built-in reader at $disk${NC}" >&2
                    echo "$disk"
                    return 0
                fi
            fi
        fi
    done

    echo -e "${RED}Error: No SD card found in built-in reader${NC}" >&2
    return 1
}

# Function to download Raspberry Pi OS image with caching
download_raspi_os() {
    local output_file="$1"

    mkdir -p "$CACHE_DIR"
    local filename=$(basename "$RASPI_IMAGE_URL")
    local cached_file="$CACHE_DIR/$filename"

    if [ -f "$cached_file" ]; then
        echo -e "${GREEN}✓ Using cached image${NC}"
        cp "$cached_file" "$output_file"
        return 0
    fi

    echo -e "${YELLOW}Downloading Raspberry Pi OS image...${NC}"
    curl -L -o "$cached_file" "$RASPI_IMAGE_URL"
    cp "$cached_file" "$output_file"
    echo -e "${GREEN}✓ Image cached for future use${NC}"
}

# Function to write image to SD card
write_image_to_sd() {
    local image_file="$1"
    local device="$2"

    echo -e "${YELLOW}Writing image to SD card...${NC}"
    echo "This will take several minutes..."

    # Unmount any mounted partitions
    diskutil unmountDisk force "$device" || true

    # Decompress and write
    if command -v pv >/dev/null 2>&1; then
        xzcat "$image_file" | pv | sudo dd of="$device" bs=4m
    else
        echo "Tip: Install 'pv' (brew install pv) to see progress"
        xzcat "$image_file" | sudo dd of="$device" bs=4m
    fi

    sync
    echo -e "${GREEN}✓ Image written successfully${NC}"
}

# Function to configure the SD card
configure_sd_card() {
    local device="$1"
    local url="$2"
    local hostname="$3"
    local username="$4"
    local password="$5"
    local wifi_ssid="$6"
    local wifi_password="$7"
    local ssh_key_file="$8"

    echo -e "${YELLOW}Configuring SD card...${NC}"

    # Wait for device to settle
    sleep 3

    # Mount the boot partition
    diskutil mountDisk "$device" || true
    sleep 2

    # Find the boot partition mount point
    local boot_mount=""
    for mount in /Volumes/bootfs /Volumes/boot /Volumes/BOOT /Volumes/NO\ NAME; do
        if [ -d "$mount" ] && [ -f "$mount/config.txt" ]; then
            boot_mount="$mount"
            break
        fi
    done

    if [ -z "$boot_mount" ]; then
        echo -e "${RED}Error: Boot partition not found${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Found boot partition at: $boot_mount${NC}"

    # 1. Enable SSH
    touch "$boot_mount/ssh"
    echo -e "${GREEN}✓ SSH enabled${NC}"

    # 2. Create user account
    local password_hash=$(openssl passwd -6 "$password")
    echo "${username}:${password_hash}" > "$boot_mount/userconf.txt"
    echo -e "${GREEN}✓ User account configured${NC}"

    # 3. Configure WiFi (if provided)
    if [ -n "$wifi_ssid" ]; then
        cat > "$boot_mount/wpa_supplicant.conf" << EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$wifi_ssid"
    psk="$wifi_password"
}
EOF
        echo -e "${GREEN}✓ WiFi configured${NC}"
    fi

    # 4. Create a simple setup script that will be run manually after first boot
    cat > "$boot_mount/setup-kiosk.sh" << EOF
#!/bin/bash
# Kiosk setup script - run this after first boot with:
# sudo bash /boot/firmware/setup-kiosk.sh

set -e

echo "Setting up kiosk mode..."

# Update hostname
hostnamectl set-hostname "$hostname"
sed -i "s/raspberrypi/$hostname/g" /etc/hosts

# Install required packages
apt-get update
apt-get install -y chromium-browser unclutter

# Create kiosk user if needed
id -u kiosk &>/dev/null || useradd -m -s /bin/bash kiosk

# Create autostart script
mkdir -p /home/$username/.config/autostart
cat > /home/$username/.config/autostart/kiosk.desktop << 'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Kiosk
Exec=/home/$username/start-kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
AUTOSTART

# Create the kiosk start script
cat > /home/$username/start-kiosk.sh << 'KIOSK'
#!/bin/bash
# Hide mouse cursor
unclutter -idle 0.1 -root &

# Start Chromium in kiosk mode
chromium-browser \\
    --kiosk \\
    --noerrdialogs \\
    --disable-infobars \\
    --disable-translate \\
    --no-first-run \\
    --fast \\
    --fast-start \\
    --disable-features=TranslateUI \\
    --disk-cache-dir=/tmp/chromium-cache \\
    --start-fullscreen \\
    "$url"
KIOSK

chmod +x /home/$username/start-kiosk.sh
chown -R $username:$username /home/$username/.config
chown $username:$username /home/$username/start-kiosk.sh

# Enable auto-login
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $username --noclear %I \$TERM
AUTOLOGIN

# Set default target to graphical
systemctl set-default graphical.target

echo "Setup complete! Rebooting..."
sleep 3
reboot
EOF

    chmod +x "$boot_mount/setup-kiosk.sh"

    # 5. Add SSH key if provided
    if [ -f "$ssh_key_file" ]; then
        mkdir -p "$boot_mount/ssh-keys"
        cp "$ssh_key_file" "$boot_mount/ssh-keys/authorized_keys"
        echo -e "${GREEN}✓ SSH key copied${NC}"
    fi

    # 6. Create a README
    cat > "$boot_mount/README-KIOSK.txt" << EOF
Raspberry Pi Kiosk Setup
========================

This SD card has been prepared for kiosk mode.

After first boot:
1. SSH into the Pi: ssh $username@$hostname.local
2. Run: sudo bash /boot/firmware/setup-kiosk.sh
3. The Pi will reboot into kiosk mode

To change the URL later:
- Edit /home/$username/start-kiosk.sh
- Reboot

Configuration:
- URL: $url
- Hostname: $hostname
- Username: $username
- WiFi SSID: $wifi_ssid
EOF

    # Sync and unmount
    sync
    sleep 2
    diskutil eject "$device"

    echo -e "${GREEN}✓ SD card configured successfully${NC}"
}

# Main function
main() {
    echo -e "${GREEN}Raspberry Pi OS Simple Kiosk Setup${NC}"
    echo "====================================="
    echo

    # Parse arguments
    local url=""
    local wifi_ssid=""
    local wifi_password=""
    local hostname="kiosk-pi"
    local username="pi"
    local password="raspberry"
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
            --ssh-key)
                ssh_key_file="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 --url <url> [options]"
                echo
                echo "Required:"
                echo "  --url <url>              URL to display in kiosk mode"
                echo
                echo "Optional:"
                echo "  --hostname <name>        Hostname (default: kiosk-pi)"
                echo "  --username <user>        Username (default: pi)"
                echo "  --password <pass>        Password (default: raspberry)"
                echo "  --wifi-ssid <ssid>       WiFi network name"
                echo "  --wifi-password <pass>   WiFi password"
                echo "  --ssh-key <file>         SSH public key file"
                echo
                echo "Example:"
                echo "  $0 --url https://example.com --wifi-ssid MyNetwork --wifi-password pass123"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$url" ]; then
        echo -e "${RED}Error: --url is required${NC}"
        echo "Run with --help for usage"
        exit 1
    fi

    # Find SD card
    local sd_device=$(find_sd_card)
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

    # Download image
    local temp_image="/tmp/raspi_os_image.img.xz"
    download_raspi_os "$temp_image"

    # Write image
    write_image_to_sd "$temp_image" "$sd_device"

    # Configure SD card
    configure_sd_card "$sd_device" "$url" "$hostname" "$username" "$password" \
                     "$wifi_ssid" "$wifi_password" "$ssh_key_file"

    echo
    echo -e "${GREEN}✓ SD card is ready!${NC}"
    echo
    echo "Next steps:"
    echo "1. Insert the SD card into your Raspberry Pi"
    echo "2. Power on and wait for boot (2-3 minutes)"
    echo "3. SSH into the Pi: ssh $username@$hostname.local"
    echo "4. Run: sudo bash /boot/firmware/setup-kiosk.sh"
    echo "5. The Pi will reboot into kiosk mode"
    echo
    echo "The setup script will:"
    echo "- Install Chromium browser"
    echo "- Configure auto-login"
    echo "- Set up kiosk mode to display: $url"
}

main "$@"