#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
# set -x           # Enable debugging output

# Configuration
readonly RASPBIAN_URL="https://downloads.raspberrypi.com/raspios_full_arm64/images/raspios_full_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64-full.img.xz"
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

# Print all candidate paths with helpful info
printf "\nCandidate SD card paths:\n"
diskutil list 2>/dev/null | grep -E "^/dev/disk[0-9]+" | while read -r disk_line; do
    disk=$(echo "$disk_line" | awk '{print $1}')
    if diskutil info "$disk" 2>/dev/null | grep -qE "(internal|synthesized|APFS Container|APPLE SSD)"; then
        continue
    fi
    size=$(diskutil info "$disk" 2>/dev/null | grep "Disk Size" | awk -F: '{print $2}' | xargs)
    name=$(diskutil info "$disk" 2>/dev/null | grep "Device / Media Name" | awk -F: '{print $2}' | xargs)
    printf "%s - %s - %s\n" "$disk" "$name" "$size"
done

printf "\nPlease enter the SD card device path (e.g., /dev/disk4): "
read -r SD_CARD

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

printf "Found SD card: %s\n" "${SD_CARD}"

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

# Create firstrun.sh script - the modern way for Raspberry Pi OS first-boot setup
printf "Creating first-run setup script...\n"
cat > "${BOOT_MOUNT}/firstrun.sh" << 'EOF'
#!/bin/bash

set +e

CURRENT_HOSTNAME=$(hostname)

# Update package list (chromium already installed in full image)
apt-get update

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
@/home/panic/launch.sh "${KIOSK_URL}"
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
        /home/panic/launch.sh "${KIOSK_URL}" &
    fi
    sleep 10
done
WATCHDOG_EOF

chmod +x /home/panic/kiosk-watchdog.sh
chown panic:panic /home/panic/kiosk-watchdog.sh

# Add watchdog to autostart as well
echo "@/home/panic/kiosk-watchdog.sh &" >> /home/panic/.config/lxsession/LXDE-pi/autostart

rm -f /boot/firstrun.sh
sed -i 's| systemd.run_success_action=reboot||g' /boot/cmdline.txt
exit 0
EOF

chmod +x "${BOOT_MOUNT}/firstrun.sh"

# Just copy the launch script as-is
chmod +x "${BOOT_MOUNT}/launch.sh"

# Add firstrun.sh to cmdline.txt
if [[ -f "${BOOT_MOUNT}/cmdline.txt" ]]; then
    # Add systemd.run parameters to trigger firstrun.sh
    sed -i '' 's/$/ systemd.run="\/boot\/firstrun.sh" systemd.run_success_action=reboot systemd.unit=kernel-command-line.target/' "${BOOT_MOUNT}/cmdline.txt"
fi

# Unmount SD card
printf "Unmounting SD card...\n"
diskutil unmountDisk "${SD_CARD}"

# Cleanup
rm -rf "${TEMP_DIR}"

printf "Setup complete! SD card is ready for Raspberry Pi.\n"
printf "The launch.sh script will automatically run on startup with URL: %s\n" "${KIOSK_URL}"
printf "WiFi will automatically connect to network: %s\n" "${WIFI_SSID}"
printf "User 'panic' will be automatically created and logged in (no password required).\n"
