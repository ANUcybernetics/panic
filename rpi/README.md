# Raspberry Pi Kiosk Scripts

This directory contains scripts to create, test, and deploy Raspberry Pi kiosk
images that boot directly into a fullscreen Chromium browser.

## Overview

The scripts use a two-stage approach for optimal performance:

**Stage 1: Base Image Preparation (One-time)**

- `prepare-base-image.sh` - Creates `panic-kiosk-base.img` with packages
  pre-installed in QEMU
- Installs desktop components and Chromium in emulated environment
- Takes 15-30 minutes but only needs to be done once

**Stage 2: Final Image Creation (Fast)**

- `create-final-image.sh` - Creates `panic-kiosk.img` from base with specific
  URL
- Takes seconds since packages are already installed
- Each kiosk deployment gets its own URL

**Testing and Deployment**

- `run-qemu.sh` - Tests images locally using QEMU emulation (macOS, with 1GB
  RAM)
- `burn-sdcard.sh` - Burns images to SD cards using the built-in SDXC reader
- `workflow.sh` - Orchestrates the complete workflow
- `cleanup.sh` - Development utility to clean up images and processes

## Quick Start

### Prerequisites

- macOS (scripts are designed for macOS)
- WiFi credentials set as environment variables
- For QEMU testing: `brew install qemu`
- SSH key pair automatically created (`~/.ssh/panic_rpi_ssh`)

### Two-Stage Workflow

```bash
# Step 1: One-time base image preparation (15-30 minutes)
export WIFI_SSID="YourWiFiNetwork"
export WIFI_PASSWORD="YourWiFiPassword"
./workflow.sh prepare-base

# Step 2: Fast final image creation (seconds)
./workflow.sh create https://your-kiosk-url.com
./workflow.sh test https://your-kiosk-url.com
./workflow.sh burn https://your-kiosk-url.com
```

## Detailed Usage

### workflow.sh Commands

**Two-Stage Workflow**

```bash
# One-time base preparation
./workflow.sh prepare-base

# Fast final image operations
./workflow.sh create <url>
./workflow.sh test <url>
./workflow.sh burn <url>
```

**Existing Image Operations**

```bash
# Test existing panic-kiosk.img
./workflow.sh test-only
./workflow.sh test-only-nographic

# Burn existing panic-kiosk.img to SD card
./workflow.sh burn-only
```

### Individual Scripts

#### prepare-base-image.sh

Creates `panic-kiosk-base.img` with packages pre-installed:

```bash
WIFI_SSID="Network" WIFI_PASSWORD="password" ./prepare-base-image.sh
```

- Downloads base Raspbian Lite image (cached in `~/.raspios-images/`)
- Configures WiFi, SSH, and automatic user creation
- Runs first-boot setup in QEMU (installs desktop packages)
- Takes 15-30 minutes but only needs to be done once
- Outputs to `panic-kiosk-base.img`

#### create-final-image.sh

Creates `panic-kiosk.img` from prepared base:

```bash
./create-final-image.sh <url>
```

- Copies `panic-kiosk-base.img` to `panic-kiosk.img`
- Embeds the target URL into the launch script
- Takes seconds since packages are already installed
- No WiFi credentials needed (preserved from base image)

#### run-qemu.sh

Tests `panic-kiosk.img` locally using QEMU:

```bash
./run-qemu.sh
```

- Requires `qemu-system-aarch64` (install with `brew install qemu`)
- Downloads required firmware files automatically
- Emulates Raspberry Pi 3B with ARM Cortex-A53
- **Resources**: 1GB RAM, 4 CPU cores (raspi3b machine limits)
- Opens Cocoa display window showing the Pi desktop
- Forwards SSH on port 5555 with passwordless access
- SSH command: `ssh -i ~/.ssh/panic_rpi_ssh -p 5555 panic@localhost`

#### burn-sdcard.sh

Burns `panic-kiosk.img` to SD cards:

```bash
./burn-sdcard.sh
```

- Automatically detects "Built In SDXC Reader"
- Safety checks to prevent burning to system disks
- Shows confirmation prompt with SD card details
- Uses `dd` with progress display for burning

#### ssh-qemu.sh

Helper script for SSH access to Pi running in QEMU:

```bash
# Connect to Pi via SSH
./ssh-qemu.sh
./ssh-qemu.sh connect

# Test SSH connection
./ssh-qemu.sh test

# Show Pi system status
./ssh-qemu.sh status

# Show recent logs
./ssh-qemu.sh logs

# Reboot/shutdown Pi
./ssh-qemu.sh reboot
./ssh-qemu.sh shutdown
```

- Uses automatically created SSH key for passwordless access
- No need to remember SSH commands or key paths
- Provides system diagnostics and control

#### test-qemu.sh

Diagnostic script to troubleshoot QEMU boot issues:

```bash
./test-qemu.sh
```

- Tests different QEMU machine configurations
- Checks image structure and boot files
- Validates network connectivity
- Helps identify boot problems

## Image Structure

### Boot Process

**Two-Stage Images**

1. **First Boot**:

   - Desktop packages already installed (no delays!)
   - Updates launch script with specific URL
   - Auto-login as user "panic"
   - Starts LXDE and launches Chromium kiosk immediately

2. **Subsequent Boots**:
   - Auto-login as user "panic"
   - Start LXDE desktop environment
   - LXDE autostart kills desktop components and launches Chromium kiosk
   - Watchdog process monitors and restarts Chromium if needed

### User Configuration

- **User**: `panic` (password: `panic`)
- **Auto-login**: Enabled via raspi-config (on physical Pi)
- **Manual login**: Required in QEMU (username: `panic`, password: `panic`)
- **SSH**: Enabled by default with passwordless key-based access
- **SSH Key**: Automatically created at `~/.ssh/panic_rpi_ssh`
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
- **Base Images**: Downloaded Raspbian images cached automatically
- **Prepared Base**: `panic-kiosk-base.img` (packages pre-installed)
- **Final Image**: `panic-kiosk.img` (ready to burn)
- **Temp Images**: `panic-kiosk-temp.img` (used during base preparation)

### On Raspberry Pi

- **Launch Script**: `/home/panic/launch.sh`
- **Watchdog**: `/home/panic/kiosk-watchdog.sh`
- **LXDE Config**: `/home/panic/.config/lxsession/LXDE-pi/autostart`
- **Boot Scripts**: `/boot/firmware/launch.sh`,
  `/boot/firmware/update-launch.sh`

## Troubleshooting

### Development Utilities

```bash
# Clean up for fresh start
./cleanup.sh --all

# Kill QEMU and clean SSH
./cleanup.sh --qemu --ssh

# Remove just base image to force rebuild
./cleanup.sh --base
```

### QEMU Issues

- Ensure QEMU is installed: `brew install qemu`
- Firmware files are extracted automatically from the Pi image to
  `~/.raspios-images/firmware/`
- **Resources**: Uses 1GB RAM and 4 CPU cores for good performance
- If display doesn't appear, check that `panic-kiosk.img` was created
  successfully
- **Login in QEMU**: Use username `panic` and password `panic` at the text login
  prompt if needed
- **Two-stage images**: Boot directly to kiosk (no first-boot delays!)
- **SSH Access**: SSH forwarded to localhost:5555 for remote access

### SD Card Issues

- Ensure SD card is inserted in built-in SDXC reader
- Check that the card isn't write-protected
- Verify sufficient space (images are ~4GB+)
- If image not found, run `./workflow.sh create <url>` first

### Pi Boot Issues

- **Two-stage images**: Should boot directly to kiosk (no delays)
- Check WiFi credentials are correct (set during base image preparation)
- SSH is enabled - can connect to debug
- Check launch script updates: `journalctl -u update-launch.service`

### Kiosk Issues

- Chromium logs to `/dev/null` - check systemd journal instead
- Watchdog restarts browser every 10 seconds if crashed
- LXDE autostart logs: `~/.xsession-errors`

## Security Notes

- SSH is enabled by default for debugging
- User "panic" has a default password (`panic`) - change in production
- Chromium runs with safe flags (dangerous security flags removed)
- No remote management - physical access required for changes

## Login Credentials

- **Username**: `panic`
- **Password**: `panic` (for console login if needed)
- **SSH Access**: `ssh -i ~/.ssh/panic_rpi_ssh -p 5555 panic@localhost` (QEMU)
- **SSH Access**: `ssh -i ~/.ssh/panic_rpi_ssh panic@<pi-ip>` (physical Pi)
- **SSH Helper**: `./ssh-qemu.sh` (easy QEMU access)

## AIDEV Notes

- Base image uses Raspbian Lite for minimal footprint
- Two-stage workflow pre-installs packages in QEMU for faster deployment
- HDMI configuration forces hotplug detection and audio output
- Service runs once using ConditionPathExists to prevent re-runs
- Watchdog uses pgrep to detect Chromium kiosk processes specifically
- QEMU uses raspi3b machine with 1GB RAM and 4 CPU cores (machine limits)
- SSH key pair automatically created for passwordless access
- Base image preparation can take 15-30 minutes but only done once
- Final image creation from base takes seconds
- SSH access: `ssh -i ~/.ssh/panic_rpi_ssh -p 5555 panic@localhost` (QEMU)
