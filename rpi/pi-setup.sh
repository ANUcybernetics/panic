#!/bin/bash
# AIDEV-NOTE: Curl-pipe-to-bash setup script for Pi kiosk mode
# Example usage (run on the Pi):
# curl -sSL https://raw.githubusercontent.com/ANUcybernetics/panic/main/rpi/pi-setup.sh | bash -s -- "https://panic.fly.dev"

set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Download and source shared configuration
CONFIG_URL="https://raw.githubusercontent.com/ANUcybernetics/panic/main/rpi/kiosk-config.sh"
if ! curl -sSL "$CONFIG_URL" -o /tmp/kiosk-config.sh; then
    echo "Warning: Failed to download shared config, using embedded defaults" >&2
    # Fallback to embedded configuration
    readonly KIOSK_PACKAGES="chromium-browser unclutter"
    readonly UNCLUTTER_FLAGS="-idle 0.1 -root"
    get_chromium_command() {
        local url="$1"
        echo "/usr/bin/chromium-browser --kiosk --disable-infobars --disable-session-crashed-bubble --disable-translate --disable-features=TranslateUI --no-first-run --disable-default-apps --disable-popup-blocking --disable-prompt-on-repost --no-message-box --autoplay-policy=no-user-gesture-required --disable-hang-monitor --window-position=0,0 --start-fullscreen --user-data-dir=/tmp/chromium-kiosk --disable-dev-shm-usage --no-sandbox --disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows --ozone-platform=wayland --enable-features=UseOzonePlatform --app=\"$url\""
    }
    get_unclutter_command() {
        echo "/usr/bin/unclutter $UNCLUTTER_FLAGS &"
    }
else
    source /tmp/kiosk-config.sh
fi

# Check for URL argument
if [ $# -eq 0 ]; then
    echo "Error: URL argument required" >&2
    echo "Usage: $0 <URL>" >&2
    echo "Example: curl -sSL https://raw.githubusercontent.com/ANUcybernetics/panic/main/rpi/pi-setup.sh | bash -s -- \"https://panic.fly.dev\"" >&2
    exit 1
fi

readonly URL="$1"
readonly SERVICE_NAME="kiosk"
readonly SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
readonly CURRENT_USER=$(whoami)

echo "Setting up Raspberry Pi kiosk mode for URL: $URL"
echo "Current user: $CURRENT_USER"

# AIDEV-NOTE: Core packages for kiosk mode - chromium and window management tools
echo "Installing required packages..."
sudo apt update
sudo apt upgrade -y
sudo apt install -y $KIOSK_PACKAGES

# Create systemd service file
echo "Creating systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Kiosk Mode Browser
After=graphical.target network-online.target
Wants=graphical.target network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=XDG_SESSION_TYPE=wayland
Environment=HOME=/home/$CURRENT_USER
WorkingDirectory=/home/$CURRENT_USER

# AIDEV-NOTE: Critical timing - wait for Wayland compositor before launching browser
# Wait for Wayland compositor to be ready
ExecStartPre=/bin/bash -c 'until pgrep -x labwc; do sleep 1; done'
ExecStartPre=/bin/sleep 5

# Hide mouse cursor
ExecStartPre=/bin/bash -c '$(get_unclutter_command)'

# Launch Chromium in kiosk mode with Wayland support
ExecStart=$(get_chromium_command "$URL")

# AIDEV-NOTE: Auto-restart on crash with progressive backoff
Restart=always
RestartSec=${SERVICE_RESTART_SEC:-10}
StartLimitInterval=${SERVICE_START_LIMIT_INTERVAL:-300}
StartLimitBurst=${SERVICE_START_LIMIT_BURST:-5}
KillMode=mixed

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kiosk

[Install]
WantedBy=graphical.target
EOF

# AIDEV-NOTE: Auto-login required for kiosk service to access display
echo "Configuring auto-login..."
if ! grep -q "autologin-user=$CURRENT_USER" /etc/lightdm/lightdm.conf; then
    sudo sed -i "s/#autologin-user=/autologin-user=$CURRENT_USER/" /etc/lightdm/lightdm.conf
    sudo sed -i "s/autologin-user=pi/autologin-user=$CURRENT_USER/" /etc/lightdm/lightdm.conf
fi

# AIDEV-NOTE: Power management is handled by the Wayland compositor in modern Pi OS
echo "Display power management configured by default Wayland session"

# AIDEV-NOTE: Enable service for graphical.target to start after desktop environment
echo "Enabling kiosk service..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"



echo ""
echo "✅ Kiosk service successfully installed and enabled!"
echo "🌐 URL: $URL"
echo "👤 User: $CURRENT_USER"
echo "🔧 Service: $SERVICE_NAME"
echo ""
echo "The system will reboot in 5 seconds and automatically start in kiosk mode."
echo "To check service status after reboot: sudo systemctl status $SERVICE_NAME"
echo "To view service logs: sudo journalctl -u $SERVICE_NAME -f"
echo ""

# Countdown and reboot
for i in {5..1}; do
    echo "Rebooting in $i seconds..."
    sleep 1
done

echo "Rebooting now..."
sudo reboot
