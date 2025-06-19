#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
set -x           # Enable debugging output

# Configuration
readonly URL="https://panic.fly.dev/"

printf "Quitting Chromium if it's running...\n"
if ! pkill chromium; then
    printf "No Chromium instances found running\n"
fi

# Wait for Chromium to fully quit
sleep 2

printf "Opening Chromium with specific arguments...\n"
# Launch fullscreen window
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --enable-features=OverlayScrollbar \
    --class="chromium-browser" \
    --user-data-dir=/tmp/chromium \
    --start-fullscreen \
    --enable-wayland-server \
    --ozone-platform=wayland \
    --autoplay-policy=no-user-gesture-required \
    "${URL}" >/dev/null 2>&1 &

printf "Setup complete - fullscreen window opened\n"
