#!/usr/bin/env bash

# Quick Kiosk Setup - Helper script with common configurations
# Usage: ./quick-setup.sh [preset-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Common kiosk presets - compatible with older bash versions
get_preset_url() {
    case "$1" in
        dashboard) echo "https://grafana.com/grafana/dashboards" ;;
        clock) echo "https://time.is" ;;
        weather) echo "https://weather.com" ;;
        news) echo "https://news.google.com" ;;
        calendar) echo "https://calendar.google.com" ;;
        photos) echo "https://photos.google.com" ;;
        youtube) echo "https://youtube.com" ;;
        local) echo "http://localhost:3000" ;;
        test) echo "https://example.com" ;;
        *) return 1 ;;
    esac
}

get_preset_list() {
    echo "dashboard clock weather news calendar photos youtube local test"
}

# Display available presets
show_presets() {
    echo
    log_info "Available presets:"
    echo "================================"
    for preset in $(get_preset_list); do
        local url=$(get_preset_url "$preset")
        printf "  %-12s -> %s\n" "$preset" "$url"
    done
    echo
}

# Get WiFi credentials interactively
get_wifi_credentials() {
    echo
    log_info "WiFi Configuration (optional - press Enter to skip)"
    read -p "WiFi SSID: " WIFI_SSID

    if [ -n "$WIFI_SSID" ]; then
        read -s -p "WiFi Password: " WIFI_PASSWORD
        echo  # New line after password input
        log_success "WiFi configured for: $WIFI_SSID"
    else
        log_info "Skipping WiFi configuration - use Ethernet connection"
    fi
}

# Interactive mode
interactive_setup() {
    echo
    log_info "Raspberry Pi 5 Kiosk Quick Setup"
    log_info "================================="

    show_presets

    echo "Enter a preset name, or a custom URL:"
    read -p "Choice: " choice

    # Check if it's a preset
    KIOSK_URL=$(get_preset_url "$choice" 2>/dev/null)
    if [ $? -eq 0 ]; then
        log_success "Using preset '$choice': $KIOSK_URL"
    elif [[ "$choice" =~ ^https?:// ]]; then
        KIOSK_URL="$choice"
        log_success "Using custom URL: $KIOSK_URL"
    else
        log_error "Invalid choice. Please enter a preset name or valid URL."
        exit 1
    fi

    get_wifi_credentials

    # Confirm settings
    echo
    log_info "Configuration Summary:"
    log_info "  Kiosk URL: $KIOSK_URL"
    if [ -n "$WIFI_SSID" ]; then
        log_info "  WiFi SSID: $WIFI_SSID"
    else
        log_info "  WiFi: Not configured"
    fi

    echo
    read -p "Proceed with this configuration? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled"
        exit 0
    fi
}

# Main script execution
main() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check if setup-kiosk.sh exists
    if [ ! -f "$SCRIPT_DIR/setup-kiosk.sh" ]; then
        log_error "setup-kiosk.sh not found in $SCRIPT_DIR"
        log_info "Please ensure both scripts are in the same directory"
        exit 1
    fi

    # Handle arguments
    if [ $# -eq 0 ]; then
        # Interactive mode
        interactive_setup
    elif [ $# -eq 1 ]; then
        # Single argument - check for help first
        if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
            echo "Usage: $0 [preset-name|url]"
            echo "       $0                    # Interactive mode"
            echo "       $0 dashboard          # Use dashboard preset"
            echo "       $0 https://google.com # Use custom URL"
            show_presets
            exit 0
        # Then check if it's a preset or URL
        elif KIOSK_URL=$(get_preset_url "$1" 2>/dev/null); then
            log_info "Using preset '$1': $KIOSK_URL"
        elif [[ "$1" =~ ^https?:// ]]; then
            KIOSK_URL="$1"
            log_info "Using URL: $KIOSK_URL"
        else
            log_error "Unknown preset: $1"
            show_presets
            exit 1
        fi
    else
        log_error "Too many arguments"
        log_info "Usage: $0 [preset-name|url]"
        exit 1
    fi

    # Build command arguments
    SETUP_ARGS=("$KIOSK_URL")

    if [ -n "$WIFI_SSID" ]; then
        SETUP_ARGS+=("$WIFI_SSID" "$WIFI_PASSWORD")
    fi

    # Execute main setup script
    log_info "Starting kiosk setup..."
    exec "$SCRIPT_DIR/setup-kiosk.sh" "${SETUP_ARGS[@]}"
}

# Run main function
main "$@"
