#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
# set -x           # Enable debugging output

# Configuration
# AIDEV-NOTE: Using Lite image for minimal kiosk setup, adds only needed desktop components
readonly RASPBIAN_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64-lite.img.xz"
readonly LAUNCH_SCRIPT_PATH="launch.sh"
readonly IMAGES_DIR="${HOME}/.raspios-images"

# Check for URL argument
if [ $# -eq 0 ]; then
    printf "Error: URL argument required\n" >&2
    printf "Usage: %s <URL>\n" "$0" >&2
    exit 1
fi

readonly KIOSK_URL="$1"

# Check for WiFi credentials from environment variables
if [[ -z "${WIFI_SSID:-}" ]]; then
    printf "Error: WIFI_SSID environment variable is required\n" >&2
    exit 1
fi

if [[ -z "${WIFI_PASSWORD:-}" ]]; then
    printf "Error: WIFI_PASSWORD environment variable is required\n" >&2
    exit 1
fi

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    printf "Error: This script is designed for macOS\n" >&2
    exit 1
fi

# Check if launch.sh exists
if [[ ! -f "${LAUNCH_SCRIPT_PATH}" ]]; then
    printf "Error: launch.sh not found at %s\n" "${LAUNCH_SCRIPT_PATH}" >&2
    exit 1
fi

# Find SD card device with name "Built In SDXC Reader"
printf "\nLooking for Built In SDXC Reader...\n"
SD_CARD=""
while IFS= read -r disk_line; do
    disk=$(echo "$disk_line" | awk '{print $1}')
    if diskutil info "$disk" 2>/dev/null | grep -qE "(internal|synthesized|APFS Container|APPLE SSD)"; then
        continue
    fi
    name=$(diskutil info "$disk" 2>/dev/null | grep "Device / Media Name" | awk -F: '{print $2}' | xargs)
    if [[ "$name" == "Built In SDXC Reader" ]]; then
        SD_CARD="$disk"
        break
    fi
done < <(diskutil list 2>/dev/null | grep -E "^/dev/disk[0-9]+")

if [[ -z "${SD_CARD}" ]]; then
    printf "Error: Built In SDXC Reader not found. Please insert an SD card.\n" >&2
    exit 1
fi

printf "Found Built In SDXC Reader: %s\n" "${SD_CARD}"

# Validate the entered path
if [[ ! -e "${SD_CARD}" ]]; then
    printf "Error: Device %s does not exist\n" "${SD_CARD}" >&2
    exit 1
fi

# Additional check to avoid system disks
if diskutil info "${SD_CARD}" 2>/dev/null | grep -qE "(internal.*APFS|synthesized|APPLE SSD)" >/dev/null; then
    printf "Error: %s appears to be a system disk. Please select an SD card.\n" "${SD_CARD}" >&2
    exit 1
fi

if [[ -z "${SD_CARD}" ]]; then
    printf "Error: No SD card found. Please insert an SD card.\n" >&2
    exit 1
fi

# Unmount SD card
printf "Unmounting SD card...\n"
diskutil unmountDisk "${SD_CARD}"

# Create images directory if it doesn't exist
mkdir -p "${IMAGES_DIR}"

# Extract filename from URL
IMAGE_FILENAME=$(basename "${RASPBIAN_URL}")
IMAGE_FILE="${IMAGES_DIR}/${IMAGE_FILENAME}"

# Download Raspbian image if not already present
if [[ -f "${IMAGE_FILE}" ]]; then
    printf "Using existing Raspbian image: %s\n" "${IMAGE_FILE}"
else
    printf "Downloading Raspbian image...\n"
    curl -L -o "${IMAGE_FILE}" "${RASPBIAN_URL}"
fi

# Extract image
printf "Extracting image...\n"
TEMP_DIR=$(mktemp -d)
EXTRACTED_IMAGE="${TEMP_DIR}/raspbian.img"
xz -d -c "${IMAGE_FILE}" > "${EXTRACTED_IMAGE}"

# Write image to SD card
printf "Writing image to SD card (this may take several minutes)...\n"
sudo dd if="${EXTRACTED_IMAGE}" of="${SD_CARD}" bs=4m status=progress

# Mount the boot partition
printf "Mounting boot partition...\n"
sleep 2
diskutil mountDisk "${SD_CARD}"

# Find boot partition mount point
BOOT_MOUNT=""
for mount in /Volumes/*; do
    if [[ -f "${mount}/config.txt" ]]; then
        BOOT_MOUNT="${mount}"
        break
    fi
done

if [[ -z "${BOOT_MOUNT}" ]]; then
    printf "Error: Could not find boot partition\n" >&2
    exit 1
fi

printf "Boot partition mounted at: %s\n" "${BOOT_MOUNT}"

# Enable SSH
touch "${BOOT_MOUNT}/ssh"

# Configure WiFi credentials
printf "Configuring WiFi credentials...\n"
cat > "${BOOT_MOUNT}/wpa_supplicant.conf" << EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="${WIFI_SSID}"
    psk="${WIFI_PASSWORD}"
}
EOF

# Configure automatic user creation to skip user setup wizard
printf "Configuring automatic user creation...\n"
cat > "${BOOT_MOUNT}/userconf.txt" << EOF
panic:\$6\$SALT\$N1UQkqPOmWMjGWpgXCNa8BKdqqXkWBCN0hwQa0Xjdqw5VGzKEGNE1URF6/rFMoq3RRdT1bXNQkOSJdvBAL61U0
EOF



# Copy launch script to boot partition
cp "${LAUNCH_SCRIPT_PATH}" "${BOOT_MOUNT}/launch.sh"

# Create setup script for systemd oneshot service
printf "Creating kiosk setup script...\n"
cat > "${BOOT_MOUNT}/setup-kiosk.sh" << 'EOF'
#!/bin/bash

set -e

# Update package list and install minimal desktop components
apt-get update

# Install only core Raspberry Pi desktop components needed for kiosk
apt-get install -y --no-install-recommends \
    xserver-xorg \
    raspberrypi-ui-mods \
    lightdm \
    chromium-browser

# Configure HDMI audio output
raspi-config nonint do_audio 2

# Set up autologin using raspi-config - this works with the existing display manager
raspi-config nonint do_boot_behaviour B4

# Ensure graphical target is set
systemctl set-default graphical.target

# Create autostart directory for LXDE desktop
mkdir -p /home/panic/.config/lxsession/LXDE-pi

# Create custom LXDE session that launches our kiosk instead of the desktop
cat > /home/panic/.config/lxsession/LXDE-pi/autostart << AUTOSTART_EOF
# Disable screen saver and power management
@xset s off
@xset -dpms
@xset s noblank

# Kill any existing desktop components to ensure clean kiosk
@pkill -f pcmanfm
@pkill -f lxpanel

# Launch our kiosk application
@/home/panic/launch.sh
AUTOSTART_EOF

# Make launch script executable and copy to home directory
chmod +x /boot/launch.sh
cp /boot/launch.sh /home/panic/launch.sh
chown -R panic:panic /home/panic/.config
chown panic:panic /home/panic/launch.sh

# Create a simple script to restart the kiosk if it crashes
cat > /home/panic/kiosk-watchdog.sh << 'WATCHDOG_EOF'
#!/bin/bash
while true; do
    if ! pgrep -f "chromium.*--kiosk" > /dev/null; then
        sleep 5
        /home/panic/launch.sh &
    fi
    sleep 10
done
WATCHDOG_EOF

chmod +x /home/panic/kiosk-watchdog.sh
chown panic:panic /home/panic/kiosk-watchdog.sh

# Add watchdog to autostart as well
echo "@/home/panic/kiosk-watchdog.sh &" >> /home/panic/.config/lxsession/LXDE-pi/autostart

# Disable the setup service so it only runs once
systemctl disable kiosk-setup.service

exit 0
EOF

chmod +x "${BOOT_MOUNT}/setup-kiosk.sh"

# Create systemd service for first-boot setup
printf "Creating systemd oneshot service...\n"
cat > "${BOOT_MOUNT}/kiosk-setup.service" << 'SERVICE_EOF'
[Unit]
Description=Kiosk First Boot Setup
After=network.target
ConditionPathExists=!/home/panic/.kiosk-setup-complete

[Service]
Type=oneshot
ExecStart=/boot/setup-kiosk.sh
ExecStartPost=/bin/touch /home/panic/.kiosk-setup-complete
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Configure HDMI settings in config.txt for reliable audio/video
cat >> "${BOOT_MOUNT}/config.txt" << 'CONFIG_EOF'

# AIDEV-NOTE: HDMI configuration for kiosk displays
# Force HDMI hotplug detection and audio
hdmi_force_hotplug=1
hdmi_drive=2
CONFIG_EOF

# Create a launch script wrapper that uses the KIOSK_URL
printf "Creating launch script wrapper...\n"
cat > "${BOOT_MOUNT}/launch.sh" << LAUNCH_EOF
#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
set -x           # Enable debugging output

# AIDEV-NOTE: Wrapper script that passes the kiosk URL to the main launch script
readonly URL="${KIOSK_URL}"

printf "Quitting Chromium if it's running...\n"
pkill -f chromium-browser || true
pkill -f chromium || true

# Wait for Chromium to fully quit
sleep 3

printf "Opening Chromium with specific arguments...\n"
# Clear any existing user data
rm -rf /tmp/chromium-kiosk

# AIDEV-NOTE: Removed dangerous security flags (--no-sandbox, --disable-web-security, --allow-running-insecure-content)
# Launch fullscreen kiosk window with safe configuration
chromium-browser \
    --kiosk \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-translate \
    --disable-features=TranslateUI \
    --no-first-run \
    --disable-default-apps \
    --disable-popup-blocking \
    --disable-prompt-on-repost \
    --no-message-box \
    --autoplay-policy=no-user-gesture-required \
    --disable-hang-monitor \
    --window-position=0,0 \
    --start-fullscreen \
    --user-data-dir=/tmp/chromium-kiosk \
    "\${URL}" >/dev/null 2>&1 &

printf "Setup complete - fullscreen window opened\n"
LAUNCH_EOF

chmod +x "${BOOT_MOUNT}/launch.sh"

# Install and enable the setup service (will be moved to proper location on first boot)
printf "Installing systemd service...\n"
mkdir -p "${BOOT_MOUNT}/systemd"
mv "${BOOT_MOUNT}/kiosk-setup.service" "${BOOT_MOUNT}/systemd/"

# Create a script to install the service on first boot
cat > "${BOOT_MOUNT}/install-service.sh" << 'INSTALL_EOF'
#!/bin/bash
cp /boot/systemd/kiosk-setup.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable kiosk-setup.service
rm -f /boot/install-service.sh
INSTALL_EOF

chmod +x "${BOOT_MOUNT}/install-service.sh"

# Add service installation to cmdline.txt
if [[ -f "${BOOT_MOUNT}/cmdline.txt" ]]; then
    sed -i.bak 's/$/ systemd.run="\/boot\/install-service.sh" systemd.run_success_action=reboot systemd.unit=kernel-command-line.target/' "${BOOT_MOUNT}/cmdline.txt" && rm -f "${BOOT_MOUNT}/cmdline.txt.bak"
fi

# Unmount SD card
printf "Unmounting SD card...\n"
diskutil unmountDisk "${SD_CARD}"

# Cleanup
rm -rf "${TEMP_DIR}"

printf "Setup complete! SD card is ready for Raspberry Pi.\n"
printf "The kiosk will automatically start on boot with URL: %s\n" "${KIOSK_URL}"
printf "WiFi will automatically connect to network: %s\n" "${WIFI_SSID}"
printf "User 'panic' will be automatically created and logged in (no password required).\n"
printf "First boot will take longer as it installs desktop components and configures the kiosk.\n"
