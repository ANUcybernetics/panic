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

    # Base64 encode the JSON to avoid any escaping issues
    local config_b64=$(printf '%s' "$config_json" | base64)

    # Output the script with base64 config embedded
    # We use a marker to inject the base64 config
    cat <<'FIRSTRUN_SCRIPT' | sed "s|__CONFIG_B64__|${config_b64}|g"
#!/bin/bash
# First-run script for Raspberry Pi OS kiosk setup

# Don't exit on error - we want to complete as much as possible
set +e

# Log everything
exec > >(tee -a /var/log/firstrun.log)
exec 2>&1

echo "========================================="
echo "Starting firstrun script at $(date)"
echo "========================================="

# Configuration passed as base64-encoded JSON
CONFIG_B64="__CONFIG_B64__"
CONFIG_JSON=$(echo "$CONFIG_B64" | base64 -d)

# Install jq for JSON parsing
echo "Installing jq for configuration parsing..."
apt-get update || echo "Warning: apt-get update failed"
apt-get install -y jq || {
    echo "Error: Failed to install jq, trying without it"
    # Fallback to basic parsing if jq fails
}

# Parse configuration with error handling
if ! HOSTNAME=$(echo "$CONFIG_JSON" | jq -r '.hostname'); then
    echo "Error: Failed to parse hostname from configuration"
    exit 1
fi
if ! USERNAME=$(echo "$CONFIG_JSON" | jq -r '.username'); then
    echo "Error: Failed to parse username from configuration"
    exit 1
fi
if ! URL=$(echo "$CONFIG_JSON" | jq -r '.url'); then
    echo "Error: Failed to parse URL from configuration"
    exit 1
fi
TAILSCALE_AUTHKEY=$(echo "$CONFIG_JSON" | jq -r '.tailscale_authkey // empty')
SSH_KEY=$(echo "$CONFIG_JSON" | jq -r '.ssh_key // empty')

# Set hostname
hostnamectl set-hostname "$HOSTNAME"
sed -i "s/raspberrypi/$HOSTNAME/g" /etc/hosts

# Setup SSH key if provided
if [ -n "$SSH_KEY" ]; then
    echo "Setting up SSH key for $USERNAME..."
    mkdir -p /home/$USERNAME/.ssh
    echo "$SSH_KEY" > /home/$USERNAME/.ssh/authorized_keys
    chmod 700 /home/$USERNAME/.ssh
    chmod 600 /home/$USERNAME/.ssh/authorized_keys
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
    echo "SSH key configured"
fi

# Enable systemd-networkd-wait-online for proper network readiness
echo "Enabling network wait service..."
systemctl enable systemd-networkd-wait-online.service

# Install required packages
echo "Installing required packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    chromium-browser unclutter wayfire wlr-randr || {
    echo "Error: Failed to install some packages, retrying..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        chromium-browser unclutter wayfire wlr-randr
}

# Install and configure Tailscale if auth key provided
if [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --hostname="$HOSTNAME"
    echo "Tailscale installed and connected"
fi

# Create Wayfire compositor service
cat > /etc/systemd/system/wayfire.service <<EOF
[Unit]
Description=Wayfire Wayland Compositor
After=systemd-user-sessions.service plymouth-quit-wait.service
Wants=dbus.socket systemd-logind.service
Conflicts=getty@tty1.service

[Service]
Type=simple
ExecStart=/usr/bin/wayfire
Restart=on-failure
RestartSec=5
User=$USERNAME
PAMName=login
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
UtmpIdentifier=tty1

# Environment
Environment="XDG_RUNTIME_DIR=/run/user/%U"
Environment="XDG_SESSION_TYPE=wayland"

[Install]
WantedBy=graphical.target
EOF

# Create kiosk service with proper dependencies
cat > /etc/systemd/system/kiosk.service <<EOF
[Unit]
Description=Chromium Kiosk Mode
After=graphical.target network-online.target wayfire.service

# Soft dependency - start even if network fails
Wants=network-online.target

# Hard dependency - display must be ready
Requires=graphical.target wayfire.service
BindsTo=wayfire.service

# Ensure filesystem is mounted
RequiresMountsFor=/boot/firmware

[Service]
Type=simple
User=$USERNAME
Group=$USERNAME

# Robust startup - wait for Wayland socket
ExecStartPre=/bin/bash -c 'for i in {1..30}; do [ -S "\${WAYLAND_DISPLAY:-/run/user/%U/wayland-1}" ] && break || sleep 1; done'
ExecStart=/usr/local/bin/chromium-kiosk.sh

# Recovery settings
Restart=always
RestartSec=10
StartLimitBurst=10
StartLimitIntervalSec=600

# If it fails 10 times in 10 minutes, run recovery
OnFailure=kiosk-recovery.service

# Environment - use systemd specifiers
Environment="XDG_RUNTIME_DIR=/run/user/%U"
Environment="WAYLAND_DISPLAY=wayland-1"

# Security and resource limits
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/boot/firmware
NoNewPrivileges=yes
MemoryMax=2G
TasksMax=512

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=chromium-kiosk

[Install]
WantedBy=graphical.target
EOF

# Create recovery service
cat > /etc/systemd/system/kiosk-recovery.service <<EOF
[Unit]
Description=Kiosk Recovery Mode
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kiosk-recovery.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kiosk-recovery
EOF

# Create recovery script
cat > /usr/local/bin/kiosk-recovery.sh <<EOF
#!/bin/bash
# Kiosk recovery script - runs when kiosk fails repeatedly

echo "Kiosk recovery mode activated"

# Log the failure
echo "Kiosk service failed repeatedly at \$(date)" >> /var/log/kiosk-failures.log
journalctl -u kiosk.service -n 50 --no-pager >> /var/log/kiosk-failures.log

# Try to restore network connectivity
systemctl restart systemd-networkd
systemctl restart wpa_supplicant

# Clear Chromium cache in case of corruption
rm -rf /tmp/chromium-cache
rm -rf /home/$USERNAME/.cache/chromium

# Reset display
systemctl restart wayfire.service

# Wait a bit before allowing restart
sleep 30

# Reset the failure counter
systemctl reset-failed kiosk.service

echo "Recovery complete, kiosk service can restart"
EOF

chmod +x /usr/local/bin/kiosk-recovery.sh

# Create chromium kiosk script
mkdir -p /usr/local/bin
cat > /usr/local/bin/chromium-kiosk.sh <<'EOF'
#!/bin/bash
# Chromium kiosk script for Wayland

# Get URL from file or use default
# Read the first line only to avoid issues with extra newlines
URL=$(head -n1 /boot/firmware/kiosk_url.txt 2>/dev/null || echo "https://panic.fly.dev")

# Log startup
logger -t chromium-kiosk "Starting Chromium kiosk with URL: $URL"

# Hide mouse cursor
unclutter -idle 0.1 -root &

# Launch Chromium in kiosk mode with Wayland support
# Wayfire will handle native resolution detection
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
    head -n1 /boot/firmware/kiosk_url.txt 2>/dev/null || echo "https://panic.fly.dev (default)"
    echo ""
    echo "Usage: kiosk-url <new-url>"
    echo "Example: kiosk-url https://example.com"
    exit 0
fi

NEW_URL="$1"

# Update the URL (using printf to avoid echo interpreting escapes)
printf '%s\n' "$NEW_URL" | sudo tee /boot/firmware/kiosk_url.txt > /dev/null

echo "Kiosk URL changed to: $NEW_URL"

# The systemd path unit will automatically detect the change and restart kiosk
echo "Waiting for automatic kiosk restart..."

# Wait for the restart to complete
sleep 2

# Check status
if sudo systemctl is-active --quiet kiosk.service; then
    echo "Done! The kiosk is now displaying: $NEW_URL"
else
    echo "Warning: Kiosk service may have failed to restart"
    echo "Check status with: sudo systemctl status kiosk.service"
fi
EOF

chmod +x /usr/local/bin/kiosk-url

# No need for auto-login with systemd service approach
# Wayfire service will handle the display directly

# Configure Wayfire as compositor (lightweight for kiosk)
apt-get install -y wayfire

# Create Wayfire config for kiosk
mkdir -p /home/$USERNAME/.config/wayfire
cat > /home/$USERNAME/.config/wayfire/wayfire.ini <<'EOF'
[core]
plugins = autostart alpha output

[autostart]
chromium = /usr/local/bin/chromium-kiosk.sh

[input]
xkb_layout = us
cursor_theme = none
cursor_size = 1

# Configure both HDMI outputs identically
# Display will work regardless of which port is used
[output:HDMI-A-1]
mode = preferred
position = 0,0
transform = normal

[output:HDMI-A-2]
mode = preferred
position = 0,0
transform = normal

[output:DSI-1]
mode = preferred
position = 0,0
transform = normal
EOF

chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

# No need for bash_profile auto-start with systemd service approach

# Enable services
echo "Enabling systemd services..."
systemctl enable wayfire.service || echo "Warning: Failed to enable wayfire.service"
systemctl enable kiosk.service || echo "Warning: Failed to enable kiosk.service"
systemctl enable kiosk-recovery.service || echo "Warning: Failed to enable kiosk-recovery.service"
systemctl set-default graphical.target || echo "Warning: Failed to set graphical.target"

# Verify services were created
echo "Verifying services..."
for service in wayfire kiosk kiosk-recovery; do
    if systemctl list-unit-files | grep -q "^${service}.service"; then
        echo "✓ ${service}.service created successfully"
    else
        echo "✗ ${service}.service NOT FOUND!"
    fi
done

# Enable linger for the user to allow user services
loginctl enable-linger $USERNAME

# Create systemd path unit to monitor URL changes
cat > /etc/systemd/system/kiosk-url-monitor.path <<EOF
[Unit]
Description=Monitor kiosk URL file for changes
After=boot.mount

[Path]
PathModified=/boot/firmware/kiosk_url.txt
Unit=kiosk-restart.service

[Install]
WantedBy=multi-user.target
EOF

# Create service to restart kiosk when URL changes
cat > /etc/systemd/system/kiosk-restart.service <<EOF
[Unit]
Description=Restart kiosk when URL changes
After=kiosk.service

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart kiosk.service
EOF

# Enable the path monitor
systemctl enable kiosk-url-monitor.path

# Create health check timer
cat > /etc/systemd/system/kiosk-health.timer <<EOF
[Unit]
Description=Periodic kiosk health check
After=kiosk.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
Unit=kiosk-health.service

[Install]
WantedBy=timers.target
EOF

# Create health check service
cat > /etc/systemd/system/kiosk-health.service <<EOF
[Unit]
Description=Check kiosk health and log status
After=kiosk.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kiosk-health-check.sh
StandardOutput=journal
StandardError=journal
EOF

# Create health check script
cat > /usr/local/bin/kiosk-health-check.sh <<EOF
#!/bin/bash
# Health check for kiosk system

echo "Running kiosk health check at \$(date)"

# Check if services are running
for service in wayfire kiosk; do
    if systemctl is-active --quiet \$service.service; then
        echo "✓ \$service.service is running"
    else
        echo "✗ \$service.service is not running"
        logger -t kiosk-health "WARNING: \$service.service is not running"
    fi
done

# Check memory usage
MEMORY_USAGE=\$(free | grep Mem | awk '{print int(\$3/\$2 * 100)}')
echo "Memory usage: \$MEMORY_USAGE%"
if [ \$MEMORY_USAGE -gt 90 ]; then
    logger -t kiosk-health "WARNING: Memory usage is high: \$MEMORY_USAGE%"
fi

# Check if URL file exists
if [ -f /boot/firmware/kiosk_url.txt ]; then
    echo "✓ URL file exists: \$(head -n1 /boot/firmware/kiosk_url.txt)"
else
    echo "✗ URL file missing"
    logger -t kiosk-health "ERROR: URL file missing"
fi

# Log disk usage
df -h /boot/firmware / | logger -t kiosk-health
EOF

chmod +x /usr/local/bin/kiosk-health-check.sh

# Enable health check timer
systemctl enable kiosk-health.timer

# Store the URL (using printf to avoid echo interpreting escapes)
printf '%s\n' "$URL" > /boot/firmware/kiosk_url.txt

# Clean up the firstrun script to prevent re-runs
rm -f /boot/firmware/firstrun.sh

# Remove our systemd.run from cmdline.txt to prevent re-runs
if [ -f /boot/firmware/cmdline.txt.bak ]; then
    cp /boot/firmware/cmdline.txt.bak /boot/firmware/cmdline.txt
    rm -f /boot/firmware/cmdline.txt.bak
fi

# Final status
echo "========================================="
echo "Firstrun script completed at $(date)"
echo "========================================="

# Reboot into kiosk mode
echo "Setup complete! Rebooting into kiosk mode in 10 seconds..."
echo "Check /var/log/firstrun.log for details"
sleep 10
reboot
FIRSTRUN_SCRIPT
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

    # Note: SSH, user account, and WiFi are now configured via custom.toml
    # But we'll keep these as fallback for older Raspberry Pi OS versions
    
    # Create empty ssh file as a fallback (custom.toml should handle this)
    touch "$boot_mount/ssh"
    
    # For older systems that don't support custom.toml, keep the traditional files
    if [ ! -f "$boot_mount/custom.toml" ]; then
        echo -e "${YELLOW}Creating fallback configuration files...${NC}"
        
        # Set up user account (userconf.txt)
        local password_hash=$(generate_password_hash "$password")
        echo "${username}:${password_hash}" > "$boot_mount/userconf.txt"
        
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
        fi
    fi

    # Configure config.txt for better 4K support on RPi5
    cat >> "$boot_mount/config.txt" << EOF

# Enable 4K60 support
hdmi_enable_4kp60=1

# Enable Wayland with RPi5-specific overlay
dtoverlay=vc4-kms-v3d-pi5
max_framebuffers=2

# Disable overscan
disable_overscan=1

# Force HDMI hotplug
hdmi_force_hotplug=1
EOF
    echo -e "${GREEN}✓ Display settings configured for 4K${NC}"

    # Read SSH public key if it exists
    local ssh_key_content=""
    if [ -f "$ssh_key_file" ]; then
        ssh_key_content=$(cat "$ssh_key_file")
        echo -e "${GREEN}✓ Found SSH key: $(basename "$ssh_key_file")${NC}"
    else
        echo -e "${YELLOW}Note: No SSH key found at $ssh_key_file${NC}"
        echo -e "${YELLOW}      Password authentication will be used${NC}"
    fi

    # Create configuration JSON (compact to avoid newlines)
    # jq properly escapes all special characters in strings
    local config_json=$(jq -n -c \
        --arg hostname "$hostname" \
        --arg username "$username" \
        --arg url "$url" \
        --arg tailscale "$tailscale_authkey" \
        --arg ssh_key "$ssh_key_content" \
        '{hostname: $hostname, username: $username, url: $url, tailscale_authkey: $tailscale, ssh_key: $ssh_key}')

    # Create the first-run script with embedded JSON configuration
    create_firstrun_script "$config_json" > "$boot_mount/firstrun.sh"
    chmod +x "$boot_mount/firstrun.sh"

    # For Raspberry Pi OS Bookworm, systemd.run in cmdline.txt is no longer supported
    # Instead, we'll use the Raspberry Pi Imager custom settings approach
    
    # Create a custom.toml file that Raspberry Pi OS will process on first boot
    cat > "$boot_mount/custom.toml" << EOF
# Raspberry Pi Imager Custom Settings
[all]
hostname = "$hostname"

[all.user]
name = "$username"
password_encrypted = "$(generate_password_hash "$password")"

[all.ssh]
enabled = true
EOF

    # Add SSH authorized keys if provided
    if [ -f "$ssh_key_file" ]; then
        local ssh_key_content=$(cat "$ssh_key_file")
        cat >> "$boot_mount/custom.toml" << EOF
authorized_keys = ["$ssh_key_content"]
EOF
    fi

    # WiFi configuration in custom.toml
    if [ -n "$wifi_ssid" ]; then
        cat >> "$boot_mount/custom.toml" << EOF

[all.wlan]
ssid = "$wifi_ssid"
password = "$wifi_password"
country = "AU"
EOF
    fi

    # Add run_on_first_boot command
    cat >> "$boot_mount/custom.toml" << EOF

[all.first_boot]
run_commands = ["/boot/firmware/firstrun.sh"]
EOF

    echo -e "${GREEN}✓ Created custom.toml for Raspberry Pi OS customization${NC}"
    
    # As a fallback, also create a service that runs on first boot
    # This uses the raspberrypi-sys-mods firstboot mechanism
    mkdir -p "$boot_mount/os_customisations"
    
    # Create a script that will be run by the firstboot service
    cat > "$boot_mount/os_customisations/firstboot.sh" << 'FIRSTBOOT_WRAPPER'
#!/bin/bash
# Wrapper script for Raspberry Pi OS firstboot

# Check if our kiosk setup script exists and run it
if [ -f /boot/firmware/firstrun.sh ]; then
    echo "Running kiosk setup script..."
    bash /boot/firmware/firstrun.sh
fi

exit 0
FIRSTBOOT_WRAPPER

    chmod +x "$boot_mount/os_customisations/firstboot.sh"

    echo -e "${GREEN}✓ Raspberry Pi OS automation configured${NC}"
    echo -e "${GREEN}✓ First-boot script will run automatically via custom.toml${NC}"
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

    # Check for required tools
    check_required_tools

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
    local test_mode=false

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
            --test)
                test_mode=true
                echo -e "${YELLOW}TEST MODE: Will skip actual SD card write${NC}"
                shift
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
    --test                       Test mode - skip actual SD card write

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

    # Test mode (no SD card write):
    $0 --test \\
       --url "https://example.com?param=value&special=char%20test" \\
       --hostname "test-pi" \\
       --username "admin" \\
       --password "test123" \\
       --wifi-ssid "TestNetwork" \\
       --wifi-password "testpass"

Features:
    - Full 4K display support via Wayland compositor
    - Native resolution detection through Wayfire
    - GPU-accelerated Chromium with Wayland backend
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

    # Find SD card (skip in test mode)
    local sd_device=""
    if [ "$test_mode" = "true" ]; then
        sd_device="/dev/disk99"  # Dummy device for test mode
        echo -e "${YELLOW}TEST MODE: Using dummy device${NC}"
    else
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
    fi

    # Download Raspberry Pi OS image
    local temp_image="/tmp/raspi_os_image.img.xz"
    download_raspi_os "$temp_image"

    # Write image to SD card
    write_image_to_sd "$temp_image" "$sd_device" "$test_mode"

    # Wait for device to settle after write
    echo "Waiting for device to settle..."
    sleep 3

    # Find boot partition
    local boot_mount=""

    if [ "$test_mode" = "true" ]; then
        # In test mode, create a temporary directory structure
        boot_mount=$(mktemp -d /tmp/raspi_boot_test.XXXXXX)
        echo -e "${YELLOW}TEST MODE: Using temporary directory: $boot_mount${NC}"

        # Create dummy files that would exist on a real boot partition
        touch "$boot_mount/config.txt"
        touch "$boot_mount/cmdline.txt"
        echo "console=serial0,115200 console=tty1 root=PARTUUID=xxxxxxxx-02 rootfstype=ext4 fsck.repair=yes rootwait" > "$boot_mount/cmdline.txt"
    else
        # Force mount the disk
        echo "Mounting partitions..."
        diskutil mountDisk "$sd_device" || true
        sleep 2

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
    fi

    # If not found, try to find FAT partition (not in test mode)
    if [ -z "$boot_mount" ] && [ "$test_mode" != "true" ]; then
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
        if [ "$test_mode" != "true" ]; then
            echo "Available volumes:"
            ls -la /Volumes/
            echo ""
            echo "Disk layout:"
            diskutil list "$sd_device"
        fi
        exit 1
    fi

    # Configure Raspberry Pi OS
    configure_raspi_os "$boot_mount" "$wifi_ssid" "$wifi_password" \
                      "$wifi_enterprise_user" "$wifi_enterprise_pass" \
                      "$url" "$hostname" "$username" "$password" \
                      "$tailscale_authkey" "$ssh_key_file"

    # Sync and eject SD card
    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Configuration complete${NC}"
        echo "Created files in: $boot_mount"
        echo -e "${GREEN}Configuration files generated successfully:${NC}"
        echo "  - ssh"
        echo "  - userconf.txt"
        [ -f "$boot_mount/wpa_supplicant.conf" ] && echo "  - wpa_supplicant.conf"
        echo "  - config.txt (appended)"
        echo "  - firstrun.sh"
        echo "  - firstrun_custom.sh"
        echo "  - cmdline.txt (modified)"
        echo ""
        echo "Test directory contents:"
        ls -la "$boot_mount"
        echo ""
        echo -e "${YELLOW}Preserving test directory for inspection: $boot_mount${NC}"
        echo "You can inspect the generated files with:"
        echo "  cat $boot_mount/firstrun_custom.sh  # Check escaping"
        echo "  cat $boot_mount/kiosk_url.txt       # After running firstrun"
        echo -e "${GREEN}✓ TEST MODE: Configuration test complete!${NC}"
    else
        echo -e "${YELLOW}Syncing and ejecting SD card...${NC}"
        sync
        sleep 2
        diskutil eject "$sd_device"
        echo -e "${GREEN}✓ SD card is ready!${NC}"
    fi
    echo
    echo "Next steps:"
    echo "1. Insert the SD card into your Raspberry Pi"
    echo "2. Power on the Pi"
    echo "3. Raspberry Pi OS will automatically:"
    echo "   - Process custom.toml for initial setup (hostname, SSH)"
    echo "   - Connect to WiFi"
    echo "   - Run kiosk setup script on first boot"
    echo "   - Install Chromium and Wayfire compositor"
    echo "   - Configure systemd services with:"
    echo "     • Automatic recovery on failure"
    echo "     • Resource limits (2GB memory)"
    echo "     • Health monitoring every 30 minutes"
    echo "     • Automatic restart on URL changes"
    echo "   - Boot into kiosk mode displaying: $url"
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
    echo "   - Full 4K display support via Wayland compositor"
    echo "   - Native resolution detection through Wayfire"
    echo "   - GPU-accelerated Chromium with Wayland backend"
    echo "   - Robust systemd service management"
    echo ""
    echo "Useful commands:"
    echo "   kiosk-url <new-url>              - Change displayed URL"
    echo "   sudo systemctl status kiosk      - Check kiosk status"
    echo "   sudo journalctl -u kiosk -f      - Follow kiosk logs"
    echo "   sudo systemctl restart kiosk     - Restart kiosk"
    echo "   sudo journalctl -u kiosk-health  - View health check logs"
}

# Run main function
main "$@"
