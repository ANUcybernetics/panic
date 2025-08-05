# Raspberry Pi Kiosk Setup

This directory contains scripts for setting up Raspberry Pi 5 devices as browser
kiosks that boot directly into fullscreen Chromium displaying a specified URL.

## Overview

The setup process uses:
- **install-sdm.sh** - Installs SDM (SD Card Image Management tool) - one-time setup
- **pi-setup.sh** - Creates customized Raspberry Pi OS SD cards with kiosk mode

The resulting installation:
- Boots directly into GPU-accelerated kiosk mode using labwc Wayland compositor (RPi OS default)
- Automatically joins your Tailscale network
- Supports native display resolutions including 4K at 60Hz
- Configures WiFi (WPA2 and enterprise 802.1X)
- Includes HDMI audio support
- Optimized specifically for Raspberry Pi 5
- Provides a `kiosk-set-url` utility for easy URL changes
- Uses official Raspberry Pi OS Bookworm (64-bit)

## Prerequisites

1. **Hardware Requirements:**
   - Raspberry Pi 5 (recommended: 8GB RAM)
   - SD card (minimum 8GB, Class 10 or better)
   - Ethernet connection for initial setup (if using WiFi)
   - HDMI display

2. **Software Requirements (Linux/Ubuntu):**
   ```bash
   # Install required tools
   sudo apt-get update
   sudo apt-get install curl xz-utils coreutils jq git
   ```

3. **Install SDM** (one-time setup):
   ```bash
   ./install-sdm.sh
   ```

4. **Get a Tailscale auth key** (optional) from
   https://login.tailscale.com/admin/settings/keys (enable "Pre-authorized")

## Usage Examples

```bash
# Basic setup with WiFi and Tailscale
./pi-setup.sh \
  --url "https://example.com" \
  --hostname "kiosk-pi" \
  --wifi-ssid "MyNetwork" \
  --wifi-password "MyPassword" \
  --tailscale-authkey "tskey-auth-..."

# Enterprise WiFi
./pi-setup.sh \
  --url "https://example.com" \
  --hostname "kiosk-display" \
  --wifi-ssid "CorpNetwork" \
  --wifi-enterprise-user "username@domain.com" \
  --wifi-enterprise-pass "password" \
  --tailscale-authkey "tskey-auth-..."

# Multiple kiosks with unique hostnames
./pi-setup.sh --hostname "lobby-display" --url "https://example.com/lobby" --tailscale-authkey "tskey-..."
./pi-setup.sh --hostname "conference-room" --url "https://example.com/schedule" --tailscale-authkey "tskey-..."

# With SSH key for passwordless login
./pi-setup.sh \
  --url "https://example.com" \
  --hostname "kiosk-1" \
  --ssh-key ~/.ssh/id_rsa.pub \
  --tailscale-authkey "tskey-auth-..."
```

## Installation Process

1. **Install SDM first** (if not already installed):
   ```bash
   ./install-sdm.sh
   ```
2. **Run the setup script** with your desired configuration
3. **Insert the SD card** when prompted (the script will detect it automatically)
4. **Confirm** the SD card device to proceed with flashing
5. **Wait** for the image to be customized and written (shows progress)
6. **Remove the SD card** when complete

## First Boot

After flashing, insert the SD card into the Pi and power on. The Pi will:

1. Boot into pre-customized Raspberry Pi OS
2. Run minimal first-boot configuration
3. Configure enterprise WiFi (if specified)
4. Join Tailscale network (if configured)
5. Start the kiosk session automatically

**First boot takes 2-3 minutes** as most configuration is done during image customization.

## Remote Management

```bash
# SSH via Tailscale (no password needed if your Tailscale user has access)
tailscale ssh panic@<hostname>

# SSH with password or key (if on same network)
ssh panic@<hostname or IP>

# Change kiosk URL
kiosk-set-url                      # View current URL
sudo kiosk-set-url https://new-url.com # Change URL

# View logs and status
systemctl --user status chromium-kiosk.service  # Check status
journalctl --user -u chromium-kiosk -f         # View logs
systemctl --user restart chromium-kiosk.service # Restart browser

# Check all kiosks on Tailscale
tailscale status | grep -E "lobby|conference|kiosk"
```

## Troubleshooting

**Pi doesn't join Tailscale network:**
- Verify the Pi has network connectivity
- Check if Tailscale auth key is still valid
- Check logs: `sudo journalctl -u tailscaled`

**Display issues:**
- labwc automatically detects and uses native resolution
- For 4K displays, ensure HDMI cable supports 4K@60Hz
- Check logs: `journalctl --user -u chromium-kiosk -n 50`
- Verify display: `wlr-randr` (when logged in via SSH)

**Audio not working:**
- Audio is configured for HDMI output by default
- Check audio: `pactl info` or `amixer`
- Test audio: `speaker-test -c 2`

**Can't SSH to Pi:**
- Ensure Pi is on network: ping the hostname or IP
- If using Tailscale: `tailscale status | grep <hostname>`
- Check SSH service: `sudo systemctl status ssh`

**WiFi not connecting:**
- Verify credentials are correct
- Check if WiFi country is set correctly
- View network status: `nmcli device status`
- Check logs: `sudo journalctl -u NetworkManager`

## Advanced Configuration

### Customizing the Installation

The script uses SDM to pre-customize the image before writing to SD card. Key configuration files:

- `/usr/local/sdm/kiosk-config` - Configuration parameters
- `/boot/firmware/kiosk-url.txt` (or `/boot/kiosk-url.txt`) - Current kiosk URL

### Display Configuration

The kiosk uses labwc compositor with automatic display detection. To modify the labwc configuration post-installation:

```bash
sudo nano /home/panic/.config/labwc/rc.xml
```

### Network Configuration

The script supports both regular WPA2 and enterprise (802.1X) WiFi networks. For other network configurations, you can use NetworkManager after installation:

```bash
# List available networks
nmcli device wifi list

# Connect to a network
nmcli device wifi connect "SSID" password "password"
```

## Platform Support

This script is designed for **Linux (Ubuntu)** systems. The previous macOS version has been deprecated due to changes in DietPi that make it incompatible with macOS.

For macOS users, we recommend:
1. Using a Linux VM or container
2. Using a Linux machine for SD card preparation
3. Using the official Raspberry Pi Imager GUI application

## Technical Details

- **Base OS:** Raspberry Pi OS Bookworm (64-bit) - May 2025 release
- **Image Customization:** SDM (https://github.com/gitbls/sdm)
- **Compositor:** labwc (Wayland) - Raspberry Pi OS default
- **Browser:** Chromium with hardware acceleration (--ozone-platform=wayland)
- **Init System:** systemd with user service for Chromium
- **Network:** NetworkManager for WiFi/Ethernet
- **Display Manager:** LightDM with auto-login
- **GPU:** Uses Raspberry Pi OS default GPU configuration

## Script Options

Run `./pi-setup.sh --help` for complete options:

```
Configuration Options:
    --url <url>                  URL to display in kiosk mode (default: https://panic.fly.dev/)
    --hostname <name>            Hostname for the Raspberry Pi (default: panic-rpi)
    --username <user>            Username for the admin account (default: panic)
    --password <pass>            Password for the admin account (default: panic)

Network Options (optional):
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK networks)
    --wifi-enterprise-user <u>   Enterprise WiFi username (use with --wifi-ssid)
    --wifi-enterprise-pass <p>   Enterprise WiFi password (use with --wifi-ssid)
    --tailscale-authkey <key>    Tailscale auth key for automatic join

Optional:
    --ssh-key <path>             Path to SSH public key for passwordless login
    --test                       Test mode - skip actual SD card write
```