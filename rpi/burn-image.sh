#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
set -x           # Enable debugging output

# Configuration
readonly RASPBIAN_URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-12-11/2023-12-11-raspios-bookworm-armhf-lite.img.xz"
readonly LAUNCH_SCRIPT_PATH="launch.sh"

# Check for URL argument
if [ $# -eq 0 ]; then
    printf "Error: URL argument required\n" >&2
    printf "Usage: %s <URL>\n" "$0" >&2
    exit 1
fi

readonly KIOSK_URL="$1"

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

# Find mounted SD card
printf "Looking for mounted SD card...\n"
SD_CARD=""
for disk in /dev/disk*; do
    if diskutil info "${disk}" 2>/dev/null | grep -q "SD Card"; then
        SD_CARD="${disk}"
        break
    fi
done

if [[ -z "${SD_CARD}" ]]; then
    printf "Error: No SD card found. Please insert an SD card.\n" >&2
    exit 1
fi

printf "Found SD card: %s\n" "${SD_CARD}"

# Unmount SD card
printf "Unmounting SD card...\n"
diskutil unmountDisk "${SD_CARD}"

# Download Raspbian image
printf "Downloading Raspbian image...\n"
TEMP_DIR=$(mktemp -d)
IMAGE_FILE="${TEMP_DIR}/raspbian.img.xz"
curl -L -o "${IMAGE_FILE}" "${RASPBIAN_URL}"

# Extract image
printf "Extracting image...\n"
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
