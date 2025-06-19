#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
set -x           # Enable debugging output

# Configuration
if [ $# -eq 0 ]; then
    printf "Error: URL argument required\n" >&2
    printf "Usage: %s <URL>\n" "$0" >&2
    exit 1
fi

readonly URL="$1"

printf "Quitting Chromium if it's running...\n"
pkill -f chromium-browser || true
pkill -f chromium || true

# Wait for Chromium to fully quit
sleep 3

printf "Opening Chromium with specific arguments...\n"
# Clear any existing user data
rm -rf /tmp/chromium-kiosk

# Launch fullscreen kiosk window optimized for full desktop
chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-web-security \
    --disable-features=VizDisplayCompositor,TranslateUI \
    --disable-ipc-flooding-protection \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-field-trial-config \
    --disable-background-networking \
    --user-data-dir=/tmp/chromium-kiosk \
    --no-first-run \
    --disable-default-apps \
    --disable-popup-blocking \
    --disable-prompt-on-repost \
    --no-message-box \
    --autoplay-policy=no-user-gesture-required \
    --allow-running-insecure-content \
    --disable-hang-monitor \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --force-device-scale-factor=1 \
    "${URL}" >/dev/null 2>&1 &

printf "Setup complete - fullscreen window opened\n"
