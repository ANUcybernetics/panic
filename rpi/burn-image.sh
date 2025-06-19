#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
# set -x           # Enable debugging output

# Configuration
readonly RASPBIAN_URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2025-05-13/2025-05-13-raspios-bookworm-armhf-lite.img.xz"
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
    printf "%s - %s (%s)\n" "$disk" "$name" "$size"
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

# Copy launch script to boot partition
cp "${LAUNCH_SCRIPT_PATH}" "${BOOT_MOUNT}/launch.sh"

# Create startup script that will run on first boot
cat > "${BOOT_MOUNT}/setup_kiosk.sh" << EOF
#!/bin/bash
# This script runs once on first boot to set up the kiosk

# Install chromium if not present
apt-get update
apt-get install -y chromium-browser

# Make launch script executable
chmod +x /boot/launch.sh

# Copy launch script to home directory
cp /boot/launch.sh /home/pi/launch.sh
chown pi:pi /home/pi/launch.sh

# Create systemd service for kiosk
cat > /etc/systemd/system/kiosk.service << 'SYSTEMD_EOF'
[Unit]
Description=Kiosk Browser
After=graphical-session.target

[Service]
Type=forking
User=pi
Environment=KIOSK_URL=${KIOSK_URL}
ExecStart=/home/pi/launch.sh ${KIOSK_URL}
Restart=always
RestartSec=10

[Install]
WantedBy=graphical-session.target
SYSTEMD_EOF

# Enable the service
systemctl enable kiosk.service

# Remove this setup script so it doesn't run again
rm /boot/setup_kiosk.sh
rm /etc/rc.local.backup 2>/dev/null || true
EOF

# Backup original rc.local and modify it to run setup on first boot
if [[ -f "${BOOT_MOUNT}/../etc/rc.local" ]]; then
    cp "${BOOT_MOUNT}/../etc/rc.local" "${BOOT_MOUNT}/../etc/rc.local.backup"
fi

cat > "${BOOT_MOUNT}/rc.local.firstboot" << 'EOF'
#!/bin/sh -e
# Run setup script on first boot
if [ -f /boot/setup_kiosk.sh ]; then
    bash /boot/setup_kiosk.sh
    # Restore original rc.local
    if [ -f /etc/rc.local.backup ]; then
        mv /etc/rc.local.backup /etc/rc.local
    else
        echo '#!/bin/sh -e' > /etc/rc.local
        echo 'exit 0' >> /etc/rc.local
    fi
    chmod +x /etc/rc.local
fi
exit 0
EOF

# Unmount SD card
printf "Unmounting SD card...\n"
diskutil unmountDisk "${SD_CARD}"

# Cleanup
rm -rf "${TEMP_DIR}"

printf "Setup complete! SD card is ready for Raspberry Pi.\n"
printf "The launch.sh script will automatically run on startup with URL: %s\n" "${KIOSK_URL}"
printf "WiFi will automatically connect to network: %s\n" "${WIFI_SSID}"
