#!/bin/bash
# Raspberry Pi OS Lite automated SD card setup using cloud-init
# More robust and debuggable kiosk setup using cloud-init

set -e
set -u
set -o pipefail

# Configuration - Using Lite image for faster SD card writing
readonly RASPI_IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz"
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
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}jq not found. Installing via Homebrew...${NC}"
        
        if ! command -v brew >/dev/null 2>&1; then
            echo -e "${RED}Error: Homebrew is required to install jq${NC}"
            echo "Install Homebrew from https://brew.sh"
            exit 1
        fi
        
        brew install jq
        echo -e "${GREEN}✓ jq installed${NC}"
    fi
    
    if ! command -v pv >/dev/null 2>&1; then
        echo -e "${YELLOW}Tip: Install 'pv' for progress display: brew install pv${NC}"
    fi
}

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
                else
                    echo -e "${RED}Error: Built-in SD card reader found at $disk but no SD card inserted${NC}" >&2
                    return 1
                fi
            fi
        fi
    done
    
    echo -e "${RED}Error: Built-in SD card reader not found${NC}" >&2
    return 1
}

# Function to download Raspberry Pi OS image with caching
download_raspi_os() {
    local output_file="$1"
    
    mkdir -p "$CACHE_DIR"
    
    local filename=$(basename "$RASPI_IMAGE_URL")
    local cached_file="$CACHE_DIR/$filename"
    
    if [ -f "$cached_file" ]; then
        echo -e "${GREEN}✓ Found cached image: $filename${NC}"
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
    
    echo -e "${YELLOW}Downloading Raspberry Pi OS Lite image...${NC}"
    if ! curl -L -o "$cached_file" "$RASPI_IMAGE_URL"; then
        echo -e "${RED}Error: Failed to download image${NC}"
        rm -f "$cached_file"
        exit 1
    fi
    
    if ! file "$cached_file" | grep -q "XZ compressed data"; then
        echo -e "${RED}Error: Downloaded file is not a valid XZ compressed image${NC}"
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
    
    echo -e "${YELLOW}Writing image to SD card...${NC}"
    echo "This will take a few minutes..."
    
    echo "Requesting administrator privileges for writing to SD card..."
    sudo -v
    
    diskutil unmountDisk force "$device" || true
    
    echo "Decompressing and writing image..."
    
    if command -v pv >/dev/null 2>&1; then
        # Lite image is smaller - approximately 2GB uncompressed
        local uncompressed_size=$((2000 * 1024 * 1024))
        xzcat "$image_file" | pv -s "$uncompressed_size" | sudo dd of="$device" bs=4m
    else
        echo "Tip: Install 'pv' (brew install pv) to see progress"
        echo "You can press Ctrl+T to see current progress"
        xzcat "$image_file" | sudo dd of="$device" bs=4m
    fi
    
    sync
    
    echo -e "${GREEN}✓ Image written successfully${NC}"
}

# Function to generate password hash
generate_password_hash() {
    local password="$1"
    echo "$password" | openssl passwd -6 -stdin
}

# Function to create cloud-init user-data
create_user_data() {
    local hostname="$1"
    local username="$2"
    local password_hash="$3"
    local url="$4"
    local tailscale_authkey="$5"
    local ssh_key="$6"
    
    cat <<EOF
#cloud-config
# Cloud-init configuration for Raspberry Pi kiosk

hostname: ${hostname}
manage_etc_hosts: true

# Create user with sudo access
users:
  - name: ${username}
    passwd: ${password_hash}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
EOF

    # Add SSH key if provided
    if [ -n "$ssh_key" ]; then
        cat <<EOF
    ssh_authorized_keys:
      - ${ssh_key}
EOF
    fi
    
    cat <<EOF

# Install required packages
packages:
  - xserver-xorg
  - x11-xserver-utils
  - xinit
  - chromium-browser
  - unclutter
  - jq

# Write configuration files
write_files:
  - path: /home/${username}/.xinitrc
    owner: ${username}:${username}
    permissions: '0755'
    content: |
      #!/bin/sh
      # Disable screen blanking
      xset s off
      xset -dpms
      xset s noblank
      
      # Hide cursor after 0.1 seconds
      unclutter -idle 0.1 -root &
      
      # Start Chromium in kiosk mode
      exec chromium-browser \\
          --kiosk \\
          --noerrdialogs \\
          --disable-infobars \\
          --disable-translate \\
          --no-first-run \\
          --fast \\
          --fast-start \\
          --disable-features=TranslateUI \\
          --disk-cache-dir=/tmp/chromium-cache \\
          --disable-features=OverscrollHistoryNavigation \\
          --disable-pinch \\
          --check-for-update-interval=31536000 \\
          --disable-component-update \\
          --autoplay-policy=no-user-gesture-required \\
          "${url}"

  - path: /etc/systemd/system/kiosk.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Chromium Kiosk
      After=multi-user.target
      
      [Service]
      Type=simple
      ExecStart=/usr/bin/xinit /home/${username}/.xinitrc -- -nocursor
      User=${username}
      Group=${username}
      Restart=always
      RestartSec=5
      StandardOutput=journal
      StandardError=journal
      
      [Install]
      WantedBy=graphical.target

  - path: /etc/systemd/system/getty@tty1.service.d/autologin.conf
    permissions: '0644'
    content: |
      [Service]
      ExecStart=
      ExecStart=-/sbin/agetty --autologin ${username} --noclear %I \$TERM

  - path: /usr/local/bin/kiosk-url
    permissions: '0755'
    content: |
      #!/bin/bash
      if [ \$# -eq 0 ]; then
          echo "Current kiosk URL: ${url}"
          echo ""
          echo "Usage: kiosk-url <new-url>"
          echo "Note: This script needs to be updated to work with cloud-init"
          exit 0
      fi
      
      NEW_URL="\$1"
      sed -i "s|exec chromium-browser.*|exec chromium-browser --kiosk --noerrdialogs --disable-infobars --disable-translate --no-first-run --fast --fast-start --disable-features=TranslateUI --disk-cache-dir=/tmp/chromium-cache --disable-features=OverscrollHistoryNavigation --disable-pinch --check-for-update-interval=31536000 --disable-component-update --autoplay-policy=no-user-gesture-required \"\$NEW_URL\"|" /home/${username}/.xinitrc
      
      echo "Kiosk URL changed to: \$NEW_URL"
      echo "Restarting kiosk..."
      
      systemctl restart kiosk
      
      echo "Done!"

  - path: /boot/firmware/kiosk-config.json
    permissions: '0644'
    content: |
      {
        "hostname": "${hostname}",
        "username": "${username}",
        "url": "${url}",
        "tailscale_authkey": "${tailscale_authkey}"
      }

# Commands to run on first boot
runcmd:
  # Enable SSH
  - systemctl enable ssh
  - systemctl start ssh
  
  # Set default target to graphical
  - systemctl set-default graphical.target
  
  # Enable kiosk service
  - systemctl enable kiosk
  
  # Install Tailscale if auth key provided
EOF

    # Add Tailscale installation if auth key is provided
    if [ -n "$tailscale_authkey" ]; then
        cat <<EOF
  - curl -fsSL https://tailscale.com/install.sh | sh
  - tailscale up --authkey="${tailscale_authkey}" --ssh --hostname="${hostname}"
EOF
    fi
    
    cat <<EOF
  
  # Start kiosk service
  - systemctl start kiosk

# Final message
final_message: "Kiosk setup complete! System is ready."

# Power state change (reboot) after cloud-init completes
power_state:
  mode: reboot
  message: "Rebooting after cloud-init setup"
  timeout: 30
  condition: True
EOF
}

# Function to create cloud-init network-config
create_network_config() {
    local wifi_ssid="$1"
    local wifi_password="$2"
    local wifi_enterprise_user="$3"
    local wifi_enterprise_pass="$4"
    
    cat <<EOF
# Network configuration for cloud-init
version: 2
ethernets:
  eth0:
    dhcp4: true
    optional: true
EOF

    # Add WiFi configuration if provided
    if [ -n "$wifi_ssid" ]; then
        echo "wifis:"
        echo "  wlan0:"
        echo "    dhcp4: true"
        echo "    optional: true"
        echo "    access-points:"
        echo "      \"${wifi_ssid}\":"
        
        if [ -n "$wifi_enterprise_user" ] && [ -n "$wifi_enterprise_pass" ]; then
            # Enterprise WiFi
            cat <<EOF
        auth:
          key-management: eap
          method: peap
          identity: "${wifi_enterprise_user}"
          password: "${wifi_enterprise_pass}"
EOF
        elif [ -n "$wifi_password" ]; then
            # Regular WiFi
            echo "        password: \"${wifi_password}\""
        fi
    fi
}

# Function to configure Raspberry Pi OS with cloud-init
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
    
    echo -e "${YELLOW}Configuring Raspberry Pi OS with cloud-init...${NC}"
    
    # Enable SSH
    touch "$boot_mount/ssh"
    echo -e "${GREEN}✓ SSH enabled${NC}"
    
    # Generate password hash
    local password_hash=$(generate_password_hash "$password")
    
    # Read SSH public key if it exists
    local ssh_key=""
    if [ -f "$ssh_key_file" ]; then
        ssh_key=$(cat "$ssh_key_file")
        echo -e "${GREEN}✓ Found SSH key: $(basename "$ssh_key_file")${NC}"
    else
        echo -e "${YELLOW}Note: No SSH key found at $ssh_key_file${NC}"
        echo -e "${YELLOW}      Password authentication will be used${NC}"
    fi
    
    # Create cloud-init user-data
    create_user_data "$hostname" "$username" "$password_hash" "$url" "$tailscale_authkey" "$ssh_key" \
        > "$boot_mount/user-data"
    echo -e "${GREEN}✓ Cloud-init user-data created${NC}"
    
    # Create cloud-init network-config
    create_network_config "$wifi_ssid" "$wifi_password" "$wifi_enterprise_user" "$wifi_enterprise_pass" \
        > "$boot_mount/network-config"
    echo -e "${GREEN}✓ Cloud-init network-config created${NC}"
    
    # Create meta-data (required by cloud-init even if empty)
    cat > "$boot_mount/meta-data" <<EOF
# meta-data file for cloud-init
# This file is required but can be empty
EOF
    echo -e "${GREEN}✓ Cloud-init meta-data created${NC}"
    
    # Enable cloud-init in cmdline.txt
    if ! grep -q "cloud-init" "$boot_mount/cmdline.txt"; then
        # Backup original cmdline.txt
        cp "$boot_mount/cmdline.txt" "$boot_mount/cmdline.txt.bak"
        
        # Add cloud-init datasource to cmdline.txt
        # This tells cloud-init to look for config files in /boot/firmware
        sed -i.bak 's/$/ systemd.run_success_action=none cloud-init=disabled/' "$boot_mount/cmdline.txt"
        
        # Actually, we need to create a firstrun script that will:
        # 1. Install cloud-init
        # 2. Move our config files to the right place
        # 3. Run cloud-init
        cat > "$boot_mount/firstrun.sh" <<'FIRSTRUN'
#!/bin/bash
set -e

echo "Installing cloud-init..."
apt-get update
apt-get install -y cloud-init

# Copy cloud-init files to proper location
mkdir -p /var/lib/cloud/seed/nocloud
cp /boot/firmware/user-data /var/lib/cloud/seed/nocloud/
cp /boot/firmware/network-config /var/lib/cloud/seed/nocloud/
cp /boot/firmware/meta-data /var/lib/cloud/seed/nocloud/

# Configure cloud-init to use NoCloud datasource
cat > /etc/cloud/cloud.cfg.d/99_datasource.cfg <<EOF
datasource_list: [ NoCloud ]
datasource:
  NoCloud:
    seedfrom: /var/lib/cloud/seed/nocloud/
EOF

# Clean cloud-init to ensure it runs fresh
cloud-init clean

# Remove firstrun.sh to prevent re-running
rm -f /boot/firmware/firstrun.sh

# Let cloud-init take over
echo "Cloud-init installed. Rebooting to run cloud-init..."
reboot
FIRSTRUN
        
        chmod +x "$boot_mount/firstrun.sh"
        
        # Restore the systemd.run command for firstrun
        sed -i.bak2 's/cloud-init=disabled/systemd.run_success_action=reboot systemd.run=\/boot\/firmware\/firstrun.sh/' "$boot_mount/cmdline.txt"
    fi
    
    echo -e "${GREEN}✓ Raspberry Pi OS cloud-init automation configured${NC}"
    echo -e "${YELLOW}Note: First boot will install cloud-init, second boot will run kiosk setup${NC}"
}

# Main function
main() {
    echo -e "${GREEN}Raspberry Pi OS Cloud-Init Kiosk Setup${NC}"
    echo "========================================"
    echo "Using cloud-init for robust configuration"
    echo
    
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: No arguments provided${NC}"
        echo
        echo "Run with --help for usage information."
        exit 1
    fi
    
    check_and_install_tools
    
    # Parse arguments
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
                cat << HELP
Usage: $0 [OPTIONS]

Required Options:
    --url <url>              URL to display in kiosk mode
    --hostname <name>        Hostname for the Raspberry Pi
    --username <user>        Username for the admin account
    --password <pass>        Password for the admin account

Network Options (at least one required if no ethernet):
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK networks)
    --wifi-enterprise-user <u>   Enterprise WiFi username (use with --wifi-ssid)
    --wifi-enterprise-pass <p>   Enterprise WiFi password (use with --wifi-ssid)

Optional:
    --tailscale-authkey <key>    Tailscale auth key for remote access
    --ssh-key <path>             Path to SSH public key (default: ~/.ssh/panic_rpi_ssh.pub)

Utility:
    --clear-cache            Clear cached images
    --help                   Show this help message

Examples:
    # Regular WiFi:
    $0 --url "https://example.com" \\
       --hostname "kiosk-pi" \\
       --username "pi" \\
       --password "raspberry" \\
       --wifi-ssid "MyNetwork" \\
       --wifi-password "MyPassword"

    # Enterprise WiFi:
    $0 --url "https://example.com" \\
       --hostname "kiosk-pi" \\
       --username "pi" \\
       --password "raspberry" \\
       --wifi-ssid "CorpNetwork" \\
       --wifi-enterprise-user "user@domain.com" \\
       --wifi-enterprise-pass "password"

This cloud-init version:
- Uses Raspberry Pi OS Lite for faster SD card writing
- Installs cloud-init on first boot
- Runs full kiosk setup on second boot
- More robust error handling and logging
- All logs available in /var/log/cloud-init-output.log
- Automatically installs SSH key for passwordless access (if found)

Boot sequence:
1. First boot: Installs cloud-init (~1-2 minutes)
2. Automatic reboot
3. Second boot: Cloud-init configures everything (~5 minutes)
4. Final reboot into kiosk mode

Monitor cloud-init progress:
    ssh $username@$hostname.local "tail -f /var/log/cloud-init-output.log"

Check cloud-init status:
    ssh $username@$hostname.local "cloud-init status --wait"
HELP
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
    
    [ -z "$url" ] && missing_args+=("--url")
    [ -z "$hostname" ] && missing_args+=("--hostname")
    [ -z "$username" ] && missing_args+=("--username")
    [ -z "$password" ] && missing_args+=("--password")
    
    if [ ${#missing_args[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required arguments: ${missing_args[*]}${NC}"
        echo
        echo "Run with --help for usage information"
        exit 1
    fi
    
    # WiFi validation
    if [ -n "$wifi_ssid" ]; then
        if [ -z "$wifi_password" ] && ([ -z "$wifi_enterprise_user" ] || [ -z "$wifi_enterprise_pass" ]); then
            echo -e "${RED}Error: WiFi SSID provided but no credentials${NC}"
            echo "Either provide --wifi-password for regular WiFi"
            echo "Or provide both --wifi-enterprise-user and --wifi-enterprise-pass for enterprise WiFi"
            exit 1
        fi
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
    
    # Download Raspberry Pi OS Lite image
    local temp_image="/tmp/raspi_os_lite.img.xz"
    download_raspi_os "$temp_image"
    
    # Write image to SD card
    write_image_to_sd "$temp_image" "$sd_device"
    
    # Wait for device to settle
    echo "Waiting for device to settle..."
    sleep 3
    
    # Mount the disk
    echo "Mounting partitions..."
    diskutil mountDisk "$sd_device" || true
    sleep 2
    
    # Find boot partition
    local boot_mount=""
    for mount in /Volumes/bootfs /Volumes/boot /Volumes/BOOT; do
        if [ -d "$mount" ] && [ -f "$mount/config.txt" ]; then
            boot_mount="$mount"
            echo -e "${GREEN}✓ Found boot partition at: $boot_mount${NC}"
            break
        fi
    done
    
    if [ -z "$boot_mount" ]; then
        echo -e "${RED}Error: Boot partition not found${NC}"
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
    echo "Boot sequence:"
    echo "1. Insert the SD card into your Raspberry Pi"
    echo "2. Power on the Pi"
    echo "3. First boot (~2 minutes):"
    echo "   - Installs cloud-init"
    echo "   - Automatic reboot"
    echo "4. Second boot (~5 minutes):"
    echo "   - Cloud-init runs full configuration"
    echo "   - Installs packages and configures kiosk"
    echo "   - Final reboot"
    echo "5. Third boot: Kiosk mode displaying $url"
    echo
    echo "Total setup time: ~8-10 minutes"
    echo
    echo "Monitor progress after second boot:"
    echo "   ssh $username@$hostname.local tail -f /var/log/cloud-init-output.log"
    echo
    if [ -n "$tailscale_authkey" ]; then
        echo "Tailscale access (after setup):"
        echo "   ssh $username@$hostname"
        if [ -f "$ssh_key_file" ]; then
            echo "   (Passwordless access via SSH key)"
        fi
        echo
    else
        if [ -f "$ssh_key_file" ]; then
            echo "SSH access:"
            echo "   ssh $username@$hostname.local"
            echo "   (Passwordless access via SSH key)"
            echo
        fi
    fi
}

# Run main function
main "$@"