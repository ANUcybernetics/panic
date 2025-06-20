#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
# set -x           # Enable debugging output

# Configuration
readonly IMAGES_DIR="${HOME}/.raspios-images"
readonly BASE_IMAGE_NAME="panic-kiosk-base.img"
readonly BASE_IMAGE_PATH="${IMAGES_DIR}/${BASE_IMAGE_NAME}"
readonly FINAL_IMAGE_NAME="panic-kiosk.img"
readonly FINAL_IMAGE_PATH="${IMAGES_DIR}/${FINAL_IMAGE_NAME}"
readonly SSH_KEY_NAME="panic_rpi_ssh"
readonly SSH_KEY_PATH="${HOME}/.ssh/${SSH_KEY_NAME}"

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

# Check if base image exists
if [[ ! -f "${BASE_IMAGE_PATH}" ]]; then
    printf "Error: Base image not found at %s\n" "${BASE_IMAGE_PATH}" >&2
    printf "Run './prepare-base-image.sh' first to create the base image\n" >&2
    exit 1
fi

printf "🔨 Creating final kiosk image from prepared base...\n"
printf "Base image: %s\n" "${BASE_IMAGE_PATH}"
printf "Kiosk URL: %s\n" "${KIOSK_URL}"
printf "Output: %s\n" "${FINAL_IMAGE_PATH}"
printf "SSH key: %s\n" "${SSH_KEY_PATH}"

# Step 1: Copy base image to final image
printf "\n📋 Copying base image...\n"
if [[ -f "${FINAL_IMAGE_PATH}" ]]; then
    printf "Removing existing final image...\n"
    rm -f "${FINAL_IMAGE_PATH}"
fi

cp "${BASE_IMAGE_PATH}" "${FINAL_IMAGE_PATH}"
printf "✅ Base image copied\n"

# Step 2: Mount the image and update the launch script with the specific URL
printf "\n🔧 Updating launch script with kiosk URL...\n"

# Attach the image as a disk
printf "Attaching image...\n"
DISK_DEVICE=$(hdiutil attach "${FINAL_IMAGE_PATH}" | grep -E '^/dev/disk[0-9]+' | head -1 | awk '{print $1}')

if [[ -z "${DISK_DEVICE}" ]]; then
    printf "Error: Could not attach final image\n" >&2
    exit 1
fi

printf "Image attached as: %s\n" "${DISK_DEVICE}"

# Function to cleanup on exit
cleanup() {
    if [[ -n "${DISK_DEVICE:-}" ]]; then
        printf "Detaching image...\n"
        hdiutil detach "${DISK_DEVICE}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Find boot partition mount point
BOOT_MOUNT=""
sleep 2
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

# Update the launch script with the specific URL
# SSH key is already configured in base image, no need to copy again
printf "SSH key already configured in base image\n"

printf "Creating launch script with URL: %s\n" "${KIOSK_URL}"
cat > "${BOOT_MOUNT}/launch.sh" << LAUNCH_EOF
#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
set -x           # Enable debugging output

# AIDEV-NOTE: Final launch script with specific kiosk URL
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

# Create script to update the launch script on next boot
cat > "${BOOT_MOUNT}/update-launch.sh" << UPDATE_EOF
#!/bin/bash
# This script runs once to update the launch script in the user's home directory
if [[ -f /boot/firmware/launch.sh ]] && [[ ! -f /home/panic/.launch-updated ]]; then
    cp /boot/firmware/launch.sh /home/panic/launch.sh
    chmod +x /home/panic/launch.sh
    chown panic:panic /home/panic/launch.sh
    echo "Launch script updated with final URL"
    touch /home/panic/.launch-updated
fi
UPDATE_EOF

chmod +x "${BOOT_MOUNT}/update-launch.sh"

# Add the update script to rc.local or create a simple systemd service
cat > "${BOOT_MOUNT}/update-launch.service" << SERVICE_EOF
[Unit]
Description=Update Launch Script
After=multi-user.target
ConditionPathExists=!/home/panic/.launch-updated

[Service]
Type=oneshot
ExecStart=/boot/firmware/update-launch.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Add installation command to cmdline.txt if not already present
if [[ -f "${BOOT_MOUNT}/cmdline.txt" ]] && ! grep -q "update-launch.service" "${BOOT_MOUNT}/cmdline.txt"; then
    # Create a backup
    cp "${BOOT_MOUNT}/cmdline.txt" "${BOOT_MOUNT}/cmdline.txt.bak"

    # Add the service installation command (simplified since SSH is already configured)
    sed -i.tmp 's/$/ systemd.run="cp \/boot\/firmware\/update-launch.service \/etc\/systemd\/system\/ \&\& systemctl daemon-reload \&\& systemctl enable update-launch.service \&\& systemctl start update-launch.service"/' "${BOOT_MOUNT}/cmdline.txt"
    rm -f "${BOOT_MOUNT}/cmdline.txt.tmp"
fi

printf "✅ Launch script updated with URL: %s\n" "${KIOSK_URL}"

# Unmount and detach the image
printf "\n💾 Finalizing image...\n"
hdiutil detach "${DISK_DEVICE}"
DISK_DEVICE=""  # Prevent cleanup from trying to detach again

printf "✅ Final kiosk image created successfully: %s\n" "${FINAL_IMAGE_PATH}"
printf "Image size: %s\n" "$(ls -lh "${FINAL_IMAGE_PATH}" | awk '{print $5}')"
printf "Kiosk URL: %s\n" "${KIOSK_URL}"

printf "\n🎉 Ready to use!\n"
printf "You can now:\n"
printf "  - Test with QEMU: ./run-qemu.sh\n"
printf "  - Burn to SD card: ./burn-sdcard.sh\n"
printf "\nSSH access (when running in QEMU):\n"
printf "  ssh -i %s -p 5555 panic@localhost\n" "${SSH_KEY_PATH}"
printf "\nThe image boots directly into fullscreen Chromium with your URL.\n"
printf "No first-boot delays - packages are already installed!\n"
