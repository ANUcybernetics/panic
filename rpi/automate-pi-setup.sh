#!/bin/bash
# Automated Raspberry Pi imaging and setup script
# This script automates the entire process of imaging an SD card and configuring it for kiosk mode

set -e
set -u
set -o pipefail

# Configuration
readonly RPI_IMAGER="/Applications/Raspberry Pi Imager.app/Contents/MacOS/rpi-imager"
readonly DEFAULT_URL="https://panic.fly.dev"
readonly DEFAULT_USER="pi"  # Default Raspberry Pi OS user
readonly DEFAULT_HOSTNAME="raspberrypi"
readonly SETUP_SCRIPT_URL="https://raw.githubusercontent.com/ANUcybernetics/panic/main/rpi/pi-setup.sh"
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

# Check if rpi-imager exists
if [ ! -x "$RPI_IMAGER" ]; then
    echo -e "${RED}Error: Raspberry Pi Imager not found at $RPI_IMAGER${NC}"
    echo "Please install from: https://www.raspberrypi.com/software/"
    exit 1
fi

# Function to find SD card device
find_sd_card() {
    echo -e "${YELLOW}Looking for SD card...${NC}"
    
    # Get list of external disks
    local external_disks=$(diskutil list external | grep "^\/" | awk '{print $1}')
    
    if [ -z "$external_disks" ]; then
        echo -e "${RED}No external disks found. Please insert an SD card.${NC}"
        return 1
    fi
    
    # If multiple external disks, let user choose
    local disk_count=$(echo "$external_disks" | wc -l | tr -d ' ')
    
    if [ "$disk_count" -gt 1 ]; then
        echo "Multiple external disks found:"
        echo "$external_disks" | while read disk; do
            echo "  $disk - $(diskutil info "$disk" | grep "Media Name" | cut -d: -f2 | xargs)"
        done
        echo -n "Enter the disk device (e.g., /dev/disk4): "
        read selected_disk
        echo "$selected_disk"
    else
        echo "$external_disks"
    fi
}

# Function to download latest Raspberry Pi OS image
download_pi_os() {
    local image_url="$1"
    local output_file="$2"
    
    echo -e "${YELLOW}Downloading Raspberry Pi OS...${NC}"
    curl -L -o "$output_file" "$image_url"
}

# Function to generate or use SSH key
setup_ssh_key() {
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo -e "${YELLOW}Generating SSH key for Raspberry Pi access...${NC}"
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "panic-rpi-access"
        echo -e "${GREEN}✓ SSH key generated at $SSH_KEY_PATH${NC}"
    else
        echo -e "${GREEN}✓ Using existing SSH key at $SSH_KEY_PATH${NC}"
    fi
    
    # Get the public key
    if [ -f "${SSH_KEY_PATH}.pub" ]; then
        cat "${SSH_KEY_PATH}.pub"
    else
        echo -e "${RED}Error: Public key not found at ${SSH_KEY_PATH}.pub${NC}"
        exit 1
    fi
}

# Function to create userconf for custom username/password
create_userconf() {
    local username="$1"
    local password="$2"
    
    # Generate encrypted password using openssl
    local encrypted_pass=$(echo "$password" | openssl passwd -6 -stdin)
    echo "${username}:${encrypted_pass}"
}

# Function to update SSH config on host machine
update_host_ssh_config() {
    local hostname="$1"
    local username="$2"
    
    local ssh_config="$HOME/.ssh/config"
    local config_entry="
# Panic Raspberry Pi Kiosk
Host panic-rpi
    HostName ${hostname}.local
    User ${username}
    IdentityFile ${SSH_KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
"
    
    # Check if entry already exists
    if [ -f "$ssh_config" ] && grep -q "Host panic-rpi" "$ssh_config"; then
        echo -e "${YELLOW}Updating existing SSH config entry...${NC}"
        # Remove old entry
        sed -i '' '/# Panic Raspberry Pi Kiosk/,/^$/d' "$ssh_config"
    fi
    
    # Add new entry
    echo "$config_entry" >> "$ssh_config"
    echo -e "${GREEN}✓ SSH config updated. You can now use: ssh panic-rpi${NC}"
}

# Function to create firstrun.sh for initial setup
create_firstrun_script() {
    local mount_point="$1"
    local url="$2"
    local hostname="$3"
    local username="$4"
    local ssh_pubkey="$5"
    
    echo -e "${YELLOW}Creating first-run setup script...${NC}"
    
    # Create firstrun.sh that will execute on first boot
    cat > "$mount_point/firstrun.sh" << 'FIRSTRUN'
#!/bin/bash
set +e  # Don't exit on error for firstrun

# Function to run the setup with retries
run_setup() {
    local url="$1"
    local max_retries=5
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        echo "Attempting to run setup script (attempt $((retry_count + 1))/$max_retries)..."
        
        # Check network connectivity
        if ping -c 1 google.com >/dev/null 2>&1; then
            # Run the setup script
            if curl -sSL "SETUP_SCRIPT_URL_PLACEHOLDER" | bash -s -- "$url"; then
                echo "Setup completed successfully!"
                return 0
            else
                echo "Setup script failed, will retry..."
            fi
        else
            echo "No network connectivity, waiting..."
        fi
        
        retry_count=$((retry_count + 1))
        sleep 10
    done
    
    echo "Failed to run setup after $max_retries attempts"
    return 1
}

# Wait for network to be ready
sleep 20

# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Set hostname
if [ -n "HOSTNAME_PLACEHOLDER" ] && [ "HOSTNAME_PLACEHOLDER" != "raspberrypi" ]; then
    echo "Setting hostname to HOSTNAME_PLACEHOLDER..."
    sudo hostnamectl set-hostname "HOSTNAME_PLACEHOLDER"
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\tHOSTNAME_PLACEHOLDER/g" /etc/hosts
fi

# Setup SSH key for the user
if [ -n "SSH_PUBKEY_PLACEHOLDER" ]; then
    echo "Setting up SSH key authentication..."
    
    # Determine user home directory
    USER_HOME="/home/USERNAME_PLACEHOLDER"
    if [ "USERNAME_PLACEHOLDER" = "root" ]; then
        USER_HOME="/root"
    fi
    
    # Create .ssh directory
    sudo mkdir -p "$USER_HOME/.ssh"
    sudo chmod 700 "$USER_HOME/.ssh"
    
    # Add SSH public key
    echo "SSH_PUBKEY_PLACEHOLDER" | sudo tee "$USER_HOME/.ssh/authorized_keys" > /dev/null
    sudo chmod 600 "$USER_HOME/.ssh/authorized_keys"
    
    # Set ownership
    if [ "USERNAME_PLACEHOLDER" != "root" ]; then
        sudo chown -R "USERNAME_PLACEHOLDER:USERNAME_PLACEHOLDER" "$USER_HOME/.ssh"
    fi
fi

# Update kiosk user in setup script if custom username
if [ "USERNAME_PLACEHOLDER" != "pi" ]; then
    export KIOSK_USER="USERNAME_PLACEHOLDER"
fi

# Run the kiosk setup
run_setup "URL_PLACEHOLDER"

# Remove this script so it doesn't run again
rm -f /boot/firstrun.sh

exit 0
FIRSTRUN
    
    # Replace placeholders
    sed -i '' "s|URL_PLACEHOLDER|$url|g" "$mount_point/firstrun.sh"
    sed -i '' "s|SETUP_SCRIPT_URL_PLACEHOLDER|$SETUP_SCRIPT_URL|g" "$mount_point/firstrun.sh"
    sed -i '' "s|HOSTNAME_PLACEHOLDER|$hostname|g" "$mount_point/firstrun.sh"
    sed -i '' "s|USERNAME_PLACEHOLDER|$username|g" "$mount_point/firstrun.sh"
    sed -i '' "s|SSH_PUBKEY_PLACEHOLDER|$ssh_pubkey|g" "$mount_point/firstrun.sh"
    
    chmod +x "$mount_point/firstrun.sh"
}

# Function to enable SSH and configure WiFi
configure_boot_partition() {
    local boot_mount="$1"
    local wifi_ssid="$2"
    local wifi_password="$3"
    local url="$4"
    local wifi_enterprise_user="$5"
    local wifi_enterprise_pass="$6"
    local hostname="$7"
    local username="$8"
    local password="$9"
    local ssh_pubkey="${10}"
    
    echo -e "${YELLOW}Configuring boot partition...${NC}"
    
    # Enable SSH
    touch "$boot_mount/ssh"
    echo -e "${GREEN}✓ SSH enabled${NC}"
    
    # Set custom username and password
    if [ -n "$username" ] && [ -n "$password" ]; then
        local userconf=$(create_userconf "$username" "$password")
        echo "$userconf" > "$boot_mount/userconf.txt"
        echo -e "${GREEN}✓ Custom user configured: $username${NC}"
    fi
    
    # Configure WiFi if credentials provided
    if [ -n "$wifi_ssid" ]; then
        if [ -n "$wifi_enterprise_user" ] && [ -n "$wifi_enterprise_pass" ]; then
            # Enterprise WPA2 (PEAP)
            cat > "$boot_mount/wpa_supplicant.conf" << EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$wifi_ssid"
    scan_ssid=1
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="$wifi_enterprise_user"
    password="$wifi_enterprise_pass"
    phase2="auth=MSCHAPV2"
    priority=1
}
EOF
            echo -e "${GREEN}✓ Enterprise WiFi (PEAP) configured${NC}"
        elif [ -n "$wifi_password" ]; then
            # Regular WPA2-PSK
            cat > "$boot_mount/wpa_supplicant.conf" << EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$wifi_ssid"
    psk="$wifi_password"
    key_mgmt=WPA-PSK
}
EOF
            echo -e "${GREEN}✓ WiFi configured${NC}"
        fi
    fi
    
    # Create custom firstrun script
    create_firstrun_script "$boot_mount" "$url" "$hostname" "$username" "$ssh_pubkey"
    echo -e "${GREEN}✓ First-run script created${NC}"
}

# Main function
main() {
    echo -e "${GREEN}Raspberry Pi Automated Setup Tool${NC}"
    echo "=================================="
    
    # Parse arguments
    local image_file=""
    local url="$DEFAULT_URL"
    local wifi_ssid=""
    local wifi_password=""
    local wifi_enterprise_user=""
    local wifi_enterprise_pass=""
    local hostname="$DEFAULT_HOSTNAME"
    local username="$DEFAULT_USER"
    local password=""
    local skip_download=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image)
                image_file="$2"
                skip_download=true
                shift 2
                ;;
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
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
    --image <file>               Use existing image file (skip download)
    --url <url>                  Kiosk URL (default: $DEFAULT_URL)
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK)
    --wifi-enterprise-user <u>   Enterprise WiFi username (for WPA2-EAP/PEAP)
    --wifi-enterprise-pass <p>   Enterprise WiFi password (for WPA2-EAP/PEAP)
    --hostname <name>            Custom hostname (default: $DEFAULT_HOSTNAME)
    --username <user>            Custom username (default: $DEFAULT_USER)
    --password <pass>            Password for custom user (required if --username is used)
    --help                       Show this help message

Examples:
    # Regular WPA2-PSK WiFi with custom user:
    $0 --url "https://example.com" --wifi-ssid "MyNetwork" --wifi-password "MyPassword" \\
       --hostname "panic-kiosk" --username "kiosk" --password "secure123"
    
    # Enterprise WPA2-EAP (PEAP) WiFi:
    $0 --url "https://example.com" --wifi-ssid "CorpNetwork" \\
       --wifi-enterprise-user "username@domain.com" \\
       --wifi-enterprise-pass "password" \\
       --hostname "panic-display"
       
After setup, you can SSH to the Pi using:
    ssh panic-rpi
    
Or directly:
    ssh -i ~/.ssh/panic_rpi_ssh <username>@<hostname>.local
EOF
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done
    
    # Validate arguments
    if [ "$username" != "$DEFAULT_USER" ] && [ -z "$password" ]; then
        echo -e "${RED}Error: --password is required when using custom --username${NC}"
        exit 1
    fi
    
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
    read confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
    
    # Download image if needed
    if [ "$skip_download" = false ]; then
        # Use Raspberry Pi OS Lite (64-bit) for better performance
        image_file="/tmp/raspios_lite_arm64.img.xz"
        download_pi_os "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-03-15/2024-03-15-raspios-bookworm-arm64-lite.img.xz" "$image_file"
    fi
    
    # Write image to SD card
    echo -e "${YELLOW}Writing image to SD card...${NC}"
    echo "This will take several minutes..."
    
    # Unmount the disk first
    diskutil unmountDisk "$sd_device"
    
    # Use rpi-imager CLI to write the image
    if [[ "$image_file" == *.xz ]]; then
        # For compressed images, we need to decompress first
        echo "Decompressing image..."
        unxz -k "$image_file" || true
        image_file="${image_file%.xz}"
    fi
    
    sudo "$RPI_IMAGER" --cli "$image_file" "$sd_device"
    
    # Wait for the disk to remount
    echo -e "${YELLOW}Waiting for disk to remount...${NC}"
    sleep 5
    
    # Find the boot partition
    boot_partition=$(diskutil list "$sd_device" | grep "boot" | awk '{print $NF}')
    if [ -z "$boot_partition" ]; then
        # Try alternative name
        boot_partition=$(diskutil list "$sd_device" | grep "bootfs" | awk '{print $NF}')
    fi
    
    if [ -n "$boot_partition" ]; then
        # Mount the boot partition if not already mounted
        boot_mount="/Volumes/boot"
        if [ ! -d "$boot_mount" ]; then
            boot_mount="/Volumes/bootfs"
        fi
        
        if [ -d "$boot_mount" ]; then
            configure_boot_partition "$boot_mount" "$wifi_ssid" "$wifi_password" "$url" "$wifi_enterprise_user" "$wifi_enterprise_pass" "$hostname" "$username" "$password" "$ssh_pubkey"
        else
            echo -e "${RED}Warning: Could not find boot partition mount point${NC}"
            echo "You'll need to manually configure the Pi on first boot"
        fi
    fi
    
    # Eject the SD card
    echo -e "${YELLOW}Ejecting SD card...${NC}"
    diskutil eject "$sd_device"
    
    # Update SSH config on host
    update_host_ssh_config "$hostname" "$username"
    
    echo -e "${GREEN}✅ SD card prepared successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Insert the SD card into your Raspberry Pi"
    echo "2. Power on the Pi"
    echo "3. The Pi will automatically:"
    echo "   - Connect to WiFi (if configured)"
    echo "   - Enable SSH access"
    echo "   - Set hostname to: $hostname"
    echo "   - Configure user: $username"
    echo "   - Install SSH key for passwordless access"
    echo "   - Download and run the kiosk setup script"
    echo "   - Reboot into kiosk mode showing: $url"
    echo ""
    echo "To monitor progress, you can SSH to the Pi after boot:"
    echo "  ssh panic-rpi"
    echo ""
    echo "Or directly:"
    echo "  ssh -i ~/.ssh/panic_rpi_ssh $username@$hostname.local"
    echo ""
    echo "The setup process will take 5-10 minutes after first boot."
}

# Run main function
main "$@"