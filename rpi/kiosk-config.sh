#!/bin/bash
# Shared configuration for Raspberry Pi kiosk setup
# This file contains common settings used by both pi-setup.sh and automate-pi-setup.sh

# Package dependencies
readonly KIOSK_PACKAGES="chromium-browser unclutter"

# Chromium browser flags for kiosk mode
readonly CHROMIUM_FLAGS=(
    "--kiosk"
    "--disable-infobars"
    "--disable-session-crashed-bubble"
    "--disable-translate"
    "--disable-features=TranslateUI"
    "--no-first-run"
    "--disable-default-apps"
    "--disable-popup-blocking"
    "--disable-prompt-on-repost"
    "--no-message-box"
    "--autoplay-policy=no-user-gesture-required"
    "--disable-hang-monitor"
    "--window-position=0,0"
    "--start-fullscreen"
    "--user-data-dir=/tmp/chromium-kiosk"
    "--disable-dev-shm-usage"
    "--no-sandbox"
    "--disable-background-timer-throttling"
    "--disable-renderer-backgrounding"
    "--disable-backgrounding-occluded-windows"
    "--ozone-platform=wayland"
    "--enable-features=UseOzonePlatform"
)

# Mouse cursor hiding settings
readonly UNCLUTTER_IDLE_TIME="0.1"  # Hide cursor after 0.1 seconds of inactivity
readonly UNCLUTTER_FLAGS="-idle $UNCLUTTER_IDLE_TIME -root"

# Service configuration
readonly SERVICE_NAME="kiosk"
readonly SERVICE_RESTART_SEC="10"
readonly SERVICE_START_LIMIT_INTERVAL="300"
readonly SERVICE_START_LIMIT_BURST="5"

# Function to get Chromium command with all flags
get_chromium_command() {
    local url="$1"
    echo "/usr/bin/chromium-browser ${CHROMIUM_FLAGS[@]} --app=\"$url\""
}

# Function to get unclutter command
get_unclutter_command() {
    echo "/usr/bin/unclutter $UNCLUTTER_FLAGS &"
}