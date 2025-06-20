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
    "${URL}" >/dev/null 2>&1 &

printf "Setup complete - fullscreen window opened\n"
