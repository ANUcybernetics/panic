# Raspberry Pi Kiosk Scripts

This directory contains scripts to create, test, and deploy Raspberry Pi kiosk
images that boot directly into a fullscreen Chromium browser.

## Overview

The scripts are organized with clear separation of concerns:

- `create-image.sh` - Creates a customized Raspberry Pi image with kiosk
  configuration
- `run-qemu.sh` - Tests images locally using QEMU emulation (macOS)
- `burn-sdcard.sh` - Burns images to SD cards using the built-in SDXC reader
- `workflow.sh` - Orchestrates common workflows (create+test, create+burn, etc.)
- `launch.sh` - Launch script that runs on the Pi (opens Chromium in kiosk mode)

## Quick Start

### Prerequisites

- macOS (scripts are designed for macOS)
- WiFi credentials set as environment variables
- For QEMU testing: `brew install qemu`

### Create and Test an Image

```bash
# Set WiFi credentials
export WIFI_SSID="YourWiFiNetwork"
export WIFI_PASSWORD="YourWiFiPassword"

# Create image and test in QEMU
./workflow.sh test https://your-kiosk-url.com
```

### Create and Burn to SD Card

```bash
# Set WiFi credentials
export WIFI_SSID="YourWiFiNetwork"
export WIFI_PASSWORD="YourWiFiPassword"

# Create image and burn to SD card
./workflow.sh burn https://your-kiosk-url.com
```

## Detailed Usage

### workflow.sh Commands

```bash
# Create customized image only
./workflow.sh create-only <url> [--name custom-name]

# Create image and test in QEMU
./workflow.sh test <url> [--name custom-name]

# Create image and burn to SD card
./workflow.sh burn <url> [--name custom-name]

# Test existing image in QEMU
./workflow.sh test-existing <image-name>

# Burn existing image to SD card
./workflow.sh burn-existing <image-name>

# List available images
./workflow.sh list
```

### Individual Scripts

#### create-image.sh

Creates a customized Raspberry Pi image with kiosk configuration:

```bash
WIFI_SSID="Network" WIFI_PASSWORD="password" ./create-image.sh <url> [output-name]
```

- Downloads base Raspbian Lite image (cached in `~/.raspios-images/`)
- Configures WiFi, SSH, and automatic user creation
- Sets up systemd service for first-boot kiosk installation
- Creates LXDE autostart configuration for kiosk mode
- Embeds the target URL into the launch script

#### run-qemu.sh

Tests images locally using QEMU:

```bash
./run-qemu.sh <image-name>
```

- Requires `qemu-system-aarch64` (install with `brew install qemu`)
- Downloads required firmware files automatically
- Emulates Raspberry Pi 3B+ with ARM Cortex-A72
- Opens Cocoa display window showing the Pi desktop
- Forwards SSH on port 5555 (ssh panic@localhost -p 5555)

#### burn-sdcard.sh

Burns images to SD cards:

```bash
./burn-sdcard.sh <image-name>
```

- Automatically detects "Built In SDXC Reader"
- Safety checks to prevent burning to system disks
- Shows confirmation prompt with SD card details
- Uses `dd` with progress display for burning

## Image Structure

### Boot Process

1. **First Boot**: Runs `kiosk-setup.service` which:

   - Installs minimal desktop components (X11, LXDE, Chromium)
   - Configures autologin for user "panic"
   - Sets up LXDE autostart configuration
   - Reboots automatically when complete

2. **Subsequent Boots**:
   - Auto-login as user "panic"
   - Start LXDE desktop environment
   - LXDE autostart kills desktop components and launches Chromium kiosk
   - Watchdog process monitors and restarts Chromium if needed

### User Configuration

- **User**: `panic` (password: `panic`)
- **Auto-login**: Enabled via raspi-config
- **SSH**: Enabled by default
- **WiFi**: Configured from environment variables

### Kiosk Configuration

- **Browser**: Chromium in `--kiosk` mode
- **Screen**: Fullscreen, no UI elements
- **Power Management**: Disabled (screen stays on)
- **Crash Recovery**: Watchdog restarts browser if it crashes
- **Audio**: HDMI audio output configured

## File Locations

### On macOS (Development)

- **Images**: `~/.raspios-images/`
- **Base Images**: Downloaded and cached automatically
- **Custom Images**: Named with timestamp or custom name

### On Raspberry Pi

- **Launch Script**: `/home/panic/launch.sh`
- **Watchdog**: `/home/panic/kiosk-watchdog.sh`
- **LXDE Config**: `/home/panic/.config/lxsession/LXDE-pi/autostart`
- **Setup Scripts**: `/boot/setup-kiosk.sh` (runs once on first boot)

## Troubleshooting

### QEMU Issues

- Ensure QEMU is installed: `brew install qemu`
- Firmware files download automatically to `~/.raspios-images/firmware/`
- If display doesn't appear, check that the image was created successfully

### SD Card Issues

- Ensure SD card is inserted in built-in SDXC reader
- Check that the card isn't write-protected
- Verify sufficient space (images are ~4GB+)

### Pi Boot Issues

- First boot takes several minutes (installing packages)
- Check WiFi credentials are correct
- SSH is enabled - can connect to debug
- Check systemd journal: `journalctl -u kiosk-setup.service`

### Kiosk Issues

- Chromium logs to `/dev/null` - check systemd journal instead
- Watchdog restarts browser every 10 seconds if crashed
- LXDE autostart logs: `~/.xsession-errors`

## Security Notes

- SSH is enabled by default for debugging
- User "panic" has a default password - change in production
- Chromium runs with safe flags (dangerous security flags removed)
- No remote management - physical access required for changes

## AIDEV Notes

- Base image uses Raspbian Lite for minimal footprint
- HDMI configuration forces hotplug detection and audio output
- Service runs once using ConditionPathExists to prevent re-runs
- Watchdog uses pgrep to detect Chromium kiosk processes specifically
