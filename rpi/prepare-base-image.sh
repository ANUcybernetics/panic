#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
# set -x           # Enable debugging output

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RASPBIAN_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64-lite.img.xz"
readonly IMAGES_DIR="${HOME}/.raspios-images"
readonly BASE_IMAGE_NAME="panic-kiosk-base.img"
readonly BASE_IMAGE_PATH="${IMAGES_DIR}/${BASE_IMAGE_NAME}"
readonly TEMP_IMAGE_NAME="panic-kiosk-temp.img"
readonly TEMP_IMAGE_PATH="${IMAGES_DIR}/${TEMP_IMAGE_NAME}"
readonly SSH_KEY_NAME="panic_rpi_ssh"
readonly SSH_KEY_PATH="${HOME}/.ssh/${SSH_KEY_NAME}"

# Function to display usage
usage() {
    cat << EOF
Usage: $0

This script creates a prepared base image by:
1. Creating a temporary kiosk image with placeholder URL
2. Running it in QEMU to complete first-boot setup (package installation)
3. Saving the prepared image as panic-kiosk-base.img

Environment Variables (required):
  WIFI_SSID       WiFi network name
  WIFI_PASSWORD   WiFi network password

Example:
  WIFI_SSID="MyNetwork" WIFI_PASSWORD="secret123" $0
EOF
}

# Check for WiFi credentials
if [[ -z "${WIFI_SSID:-}" ]]; then
    printf "Error: WIFI_SSID environment variable is required\n" >&2
    usage
    exit 1
fi

# Function to create SSH key pair if it doesn't exist
create_ssh_key() {
    if [[ ! -f "${SSH_KEY_PATH}" ]]; then
        printf "Creating SSH key pair for Pi access...\n"
        mkdir -p "${HOME}/.ssh"
        ssh-keygen -t rsa -b 4096 -f "${SSH_KEY_PATH}" -N "" -C "panic-rpi-access"
        printf "SSH key pair created: %s\n" "${SSH_KEY_PATH}"
    else
        printf "Using existing SSH key: %s\n" "${SSH_KEY_PATH}"
    fi
}

# Create SSH key pair
create_ssh_key

if [[ -z "${WIFI_PASSWORD:-}" ]]; then
    printf "Error: WIFI_PASSWORD environment variable is required\n" >&2
    usage
    exit 1
fi

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    printf "Error: This script is designed for macOS\n" >&2
    exit 1
fi

printf "🔨 Creating base kiosk image with pre-installed packages...\n"
printf "This will create: %s\n" "${BASE_IMAGE_PATH}"
printf "WiFi: %s\n" "${WIFI_SSID}"
printf "SSH key: %s\n" "${SSH_KEY_PATH}"

# Step 1: Create temporary base image
printf "\n📦 Step 1: Creating temporary base image...\n"

# Create images directory if it doesn't exist
mkdir -p "${IMAGES_DIR}"

# Download base Raspbian image if not already present
BASE_IMAGE_FILENAME=$(basename "${RASPBIAN_URL}")
BASE_IMAGE_FILE="${IMAGES_DIR}/${BASE_IMAGE_FILENAME}"

if [[ -f "${BASE_IMAGE_FILE}" ]]; then
    printf "Using existing base Raspbian image: %s\n" "${BASE_IMAGE_FILE}"
else
    printf "Downloading base Raspbian image...\n"
    curl -L -o "${BASE_IMAGE_FILE}" "${RASPBIAN_URL}"
fi

# Extract base image to create our temporary version
printf "Extracting and preparing temporary base image...\n"
xz -d -c "${BASE_IMAGE_FILE}" > "${TEMP_IMAGE_PATH}"

# Resize image to 8G for QEMU compatibility
printf "Resizing image to 8G for QEMU compatibility...\n"
if command -v qemu-img >/dev/null 2>&1; then
    qemu-img resize -f raw "${TEMP_IMAGE_PATH}" 8G
else
    printf "Warning: qemu-img not found, image may need manual resizing for QEMU\n"
fi

# Configure the temporary image
printf "Configuring temporary image...\n"
DISK_DEVICE=$(hdiutil attach "${TEMP_IMAGE_PATH}" | grep -E '^/dev/disk[0-9]+' | head -1 | awk '{print $1}')

if [[ -z "${DISK_DEVICE}" ]]; then
    printf "Error: Could not attach temporary image\n" >&2
    exit 1
fi

printf "Temporary image attached as: %s\n" "${DISK_DEVICE}"

# Function to cleanup on exit
cleanup_temp() {
    if [[ -n "${DISK_DEVICE:-}" ]]; then
        printf "Detaching temporary image...\n"
        hdiutil detach "${DISK_DEVICE}" 2>/dev/null || true
    fi
}
trap cleanup_temp EXIT

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

# Enable SSH
touch "${BOOT_MOUNT}/ssh"

# Also create SSH service enable file for systemd
cat > "${BOOT_MOUNT}/ssh-enable.sh" << 'SSH_EOF'
#!/bin/bash
systemctl enable ssh
systemctl start ssh
SSH_EOF
chmod +x "${BOOT_MOUNT}/ssh-enable.sh"

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

# Configure automatic user creation
printf "Configuring automatic user creation...\n"
cat > "${BOOT_MOUNT}/userconf.txt" << EOF
panic:\$6\$.rEV7EOxyjcWpFPy\$OcJXwrq7tUEu1dAlz330iydgY1rTkkjF6uYnjWBQKrN.DSe9N6uHX9tlhuZ//BqGSP/gMg8otF29q9i9Li5KO.
EOF

# Copy SSH public key for passwordless access
printf "Configuring SSH public key for passwordless access...\n"
if [[ -f "${SSH_KEY_PATH}.pub" ]]; then
    cp "${SSH_KEY_PATH}.pub" "${BOOT_MOUNT}/panic_rpi_ssh.pub"
    printf "✅ SSH public key copied to boot partition\n"
    printf "   Key path: %s.pub\n" "${SSH_KEY_PATH}"
    printf "   Boot location: %s/panic_rpi_ssh.pub\n" "${BOOT_MOUNT}"
else
    printf "❌ Warning: SSH public key not found at %s.pub\n" "${SSH_KEY_PATH}"
    printf "   This will prevent passwordless SSH access\n"
fi

# Configure HDMI and boot settings
printf "Configuring HDMI and boot settings...\n"
cat >> "${BOOT_MOUNT}/config.txt" << 'CONFIG_EOF'

# AIDEV-NOTE: HDMI configuration for kiosk displays
# Force HDMI hotplug detection and audio
hdmi_force_hotplug=1
hdmi_drive=2
CONFIG_EOF

# Create simple setup script and systemd service
printf "Creating setup script and service...\n"
cat > "${BOOT_MOUNT}/setup-kiosk.sh" << 'SETUP_EOF'
#!/bin/bash
exec > /tmp/kiosk-setup.log 2>&1
echo "$(date): Starting kiosk setup"

# Exit if already completed
if [[ -f /home/panic/.kiosk-setup-complete ]]; then
    echo "Setup already completed"
    exit 0
fi

# Enable SSH service first
systemctl enable ssh
systemctl start ssh

# Set up SSH key immediately
mkdir -p /home/panic/.ssh
chmod 700 /home/panic/.ssh
chown panic:panic /home/panic/.ssh

if [[ -f /boot/firmware/panic_rpi_ssh.pub ]]; then
    cp /boot/firmware/panic_rpi_ssh.pub /home/panic/.ssh/authorized_keys
    chmod 600 /home/panic/.ssh/authorized_keys
    chown panic:panic /home/panic/.ssh/authorized_keys
    rm -f /boot/firmware/panic_rpi_ssh.pub
    systemctl restart ssh
    echo "SSH key configured"
fi

# Update and install packages
apt-get update
apt-get install -y --no-install-recommends \
    xserver-xorg \
    raspberrypi-ui-mods \
    lightdm \
    chromium-browser

# Configure auto-login
raspi-config nonint do_boot_behaviour B4
systemctl set-default graphical.target

# Set up user directories
mkdir -p /home/panic/.config/lxsession/LXDE-pi
chown -R panic:panic /home/panic/.config

# Create launch script
cat > /home/panic/launch.sh << 'LAUNCH_EOF'
#!/bin/bash
echo "Base kiosk ready - launch script will be updated with final URL"
LAUNCH_EOF
chmod +x /home/panic/launch.sh
chown panic:panic /home/panic/launch.sh

# Create autostart config
cat > /home/panic/.config/lxsession/LXDE-pi/autostart << 'AUTOSTART_EOF'
@xset s off
@xset -dpms
@xset s noblank
@pkill -f pcmanfm
@pkill -f lxpanel
@/home/panic/launch.sh
AUTOSTART_EOF
chown panic:panic /home/panic/.config/lxsession/LXDE-pi/autostart

# Create watchdog
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
echo "@/home/panic/kiosk-watchdog.sh &" >> /home/panic/.config/lxsession/LXDE-pi/autostart

# Mark complete and disable service
touch /home/panic/.kiosk-setup-complete
chown panic:panic /home/panic/.kiosk-setup-complete
systemctl disable kiosk-setup
rm -f /etc/systemd/system/kiosk-setup.service

echo "$(date): Kiosk setup complete"
SETUP_EOF
chmod +x "${BOOT_MOUNT}/setup-kiosk.sh"

# Create systemd service
cat > "${BOOT_MOUNT}/kiosk-setup.service" << 'SERVICE_EOF'
[Unit]
Description=Kiosk Setup Service
After=multi-user.target
ConditionPathExists=!/home/panic/.kiosk-setup-complete

[Service]
Type=oneshot
ExecStart=/boot/firmware/setup-kiosk.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Install service via cmdline.txt
if [[ -f "${BOOT_MOUNT}/cmdline.txt" ]]; then
    sed -i.bak 's/$/ systemd.run="cp \/boot\/firmware\/kiosk-setup.service \/etc\/systemd\/system\/ \&\& systemctl daemon-reload \&\& systemctl enable kiosk-setup"/' "${BOOT_MOUNT}/cmdline.txt"
    rm -f "${BOOT_MOUNT}/cmdline.txt.bak"
fi

# Detach the temporary image
hdiutil detach "${DISK_DEVICE}"
DISK_DEVICE=""  # Prevent cleanup from trying to detach again

printf "✅ Temporary image configured\n"

printf "\n🚀 Step 2: Running first-boot setup in QEMU...\n"
printf "This will install desktop packages and may take several minutes...\n"

# Update run-qemu.sh to use our temporary image
ORIGINAL_IMAGE_NAME=$(grep "readonly IMAGE_NAME=" "${SCRIPT_DIR}/run-qemu.sh" | cut -d'"' -f2)
sed -i.bak "s/readonly IMAGE_NAME=\".*\"/readonly IMAGE_NAME=\"${TEMP_IMAGE_NAME}\"/" "${SCRIPT_DIR}/run-qemu.sh"

# Function to restore original image name
cleanup() {
    if [[ -f "${SCRIPT_DIR}/run-qemu.sh.bak" ]]; then
        mv "${SCRIPT_DIR}/run-qemu.sh.bak" "${SCRIPT_DIR}/run-qemu.sh"
    fi
}
trap cleanup EXIT

# Start QEMU and wait for manual verification
printf "Starting QEMU in graphic mode...\n"
printf "The Pi desktop will appear in a QEMU window.\n"
printf "Watch the boot process and first-boot setup there.\n\n"

"${SCRIPT_DIR}/run-qemu.sh" &
QEMU_PID=$!

printf "QEMU started with PID: %d\n" "${QEMU_PID}"
printf "\n📋 MANUAL VERIFICATION REQUIRED:\n"
printf "1. Watch the QEMU window for the Pi to boot\n"
printf "2. The setup script will run automatically and install packages\n"
printf "3. When you see the desktop appear, verify SSH works:\n"
printf "   ssh -i %s -p 5555 panic@localhost\n" "${SSH_KEY_PATH}"
printf "4. Once SSH is working and packages are installed, shut down the Pi:\n"
printf "   sudo shutdown -h now\n"
printf "5. Press ENTER here when the Pi has shut down completely\n\n"

printf "Waiting for you to verify the setup and shut down the Pi...\n"
read -p "Press ENTER when the Pi has shut down: " -r

# Make sure QEMU is stopped
if kill -0 "${QEMU_PID}" 2>/dev/null; then
    printf "Stopping QEMU...\n"
    kill "${QEMU_PID}" 2>/dev/null || true
    wait "${QEMU_PID}" 2>/dev/null || true
fi

printf "✅ QEMU has shut down\n"

# Step 3: Save the prepared image
printf "\n💾 Step 3: Saving prepared base image...\n"

# Remove any existing base image
if [[ -f "${BASE_IMAGE_PATH}" ]]; then
    printf "Removing existing base image...\n"
    rm -f "${BASE_IMAGE_PATH}"
fi

# Copy the prepared image to base image
cp "${TEMP_IMAGE_PATH}" "${BASE_IMAGE_PATH}"

# Clean up temporary image
rm -f "${TEMP_IMAGE_PATH}"

printf "✅ Base image created successfully: %s\n" "${BASE_IMAGE_PATH}"
printf "Image size: %s\n" "$(ls -lh "${BASE_IMAGE_PATH}" | awk '{print $5}')"

printf "\n🎉 Base image preparation complete!\n"
printf "\nYou can now use this base image to create kiosk images with specific URLs:\n"
printf "  ./create-final-image.sh <url>\n"
printf "\nOr use the workflow script:\n"
printf "  ./workflow.sh create-final <url>\n"
printf "  ./workflow.sh test-final <url>\n"
printf "  ./workflow.sh burn-final <url>\n"
printf "\nSSH access (when running in QEMU):\n"
printf "  ssh -i %s -p 5555 panic@localhost\n" "${SSH_KEY_PATH}"
