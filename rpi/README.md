# Raspberry Pi Kiosk Setup

This directory contains a script to set up Raspberry Pi 5 devices as browser
kiosks that boot directly into fullscreen Chromium displaying a specified URL.

## Overview

The `pi-setup.sh` script creates a fully automated [Raspberry Pi OS](https://www.raspberrypi.com/software/)
installation that:

- boots directly into GPU-accelerated kiosk mode using Wayfire compositor
- automatically joins your Tailscale network
- supports native display resolutions including 4K at 60Hz
- configures WiFi (WPA2 and enterprise 802.1X)
- includes HDMI audio support
- optimized specifically for Raspberry Pi 5
- provides a `kiosk-set-url` utility for easy URL changes

## Prerequisites

1. **Hardware Requirements:**
   - Raspberry Pi 5 (recommended: 8GB RAM)
   - SD card (minimum 8GB, Class 10 or better)
   - Ethernet connection for initial setup (if using WiFi)
   - HDMI display

2. **Software Requirements (Linux/Ubuntu):**
   ```bash
   sudo apt-get update
   sudo apt-get install curl xz-utils pv jq
   ```

3. **Get a Tailscale auth key** (optional) from
   https://login.tailscale.com/admin/settings/keys (enable "Pre-authorized")

## Usage Examples

```bash
# Basic setup with WiFi and Tailscale
./pi-setup.sh \
  --url "https://example.com" \
  --wifi-ssid "MyNetwork" \
  --wifi-password "MyPassword" \
  --tailscale-authkey "tskey-auth-..."

# Enterprise WiFi
./pi-setup.sh \
  --url "https://example.com" \
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

1. **Run the script** with your desired configuration
2. **Insert the SD card** when prompted (the script will detect it automatically)
3. **Confirm** the SD card device to proceed with flashing
4. **Wait** for the image to be written (progress bar shows ETA)
5. **Remove the SD card** when complete

## First Boot

After flashing, insert the SD card into the Pi and power on. The Pi will:

1. Boot into Raspberry Pi OS
2. Run the automated first-boot configuration
3. Set hostname and configure network
4. Install required packages (Chromium, Wayfire, etc.)
5. Join Tailscale network (if configured)
6. Configure kiosk mode
7. Reboot automatically

**First boot takes 5-10 minutes** depending on network speed and whether system updates are available.

## Remote Management

```bash
# SSH via Tailscale (no password needed if your Tailscale user has access)
tailscale ssh pi@<hostname>

# SSH with password or key (if on same network)
ssh pi@<hostname or IP>

# Change kiosk URL
sudo kiosk-set-url                    # View current URL
sudo kiosk-set-url https://new-url.com # Change URL

# View logs and status
sudo journalctl -u kiosk -f            # View kiosk logs
sudo systemctl status kiosk            # Check status
sudo systemctl restart kiosk           # Restart kiosk

# Check all kiosks on Tailscale
tailscale status | grep -E "lobby|conference|kiosk"
```

## Troubleshooting

**Pi doesn't join Tailscale network:**
- Verify the Pi has network connectivity
- Check if Tailscale auth key is still valid
- Check logs: `sudo journalctl -u tailscaled`

**Display issues:**
- Wayfire automatically detects and uses native resolution
- For 4K displays, ensure HDMI cable supports 4K@60Hz
- Check logs: `sudo journalctl -u kiosk -n 50`
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

The script creates several files on the boot partition that control the first-boot process:

- `firstrun.sh` - Main configuration script
- `kiosk-config.json` - Configuration parameters
- `userconf.txt` - User account setup
- `ssh` - Enables SSH access

### Display Configuration

The kiosk uses Wayfire compositor with automatic display detection. To force specific resolutions or handle multiple displays, you can modify the Wayfire configuration post-installation:

```bash
sudo nano /home/pi/.config/wayfire/wayfire.ini
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

- **Base OS:** Raspberry Pi OS Bookworm (64-bit)
- **Compositor:** Wayfire (Wayland)
- **Browser:** Chromium with hardware acceleration
- **Init System:** systemd with custom service units
- **Network:** NetworkManager for WiFi/Ethernet
- **GPU:** Full KMS driver with 512MB GPU memory allocation

## Script Options

Run `./pi-setup.sh --help` for complete options:

```
Configuration Options:
    --url <url>                  URL to display in kiosk mode
    --hostname <name>            Hostname for the Raspberry Pi
    --username <user>            Username for the admin account
    --password <pass>            Password for the admin account

Network Options (optional):
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK networks)
    --wifi-enterprise-user <u>   Enterprise WiFi username
    --wifi-enterprise-pass <p>   Enterprise WiFi password
    --tailscale-authkey <key>    Tailscale auth key for automatic join

Optional:
    --ssh-key <path>             Path to SSH public key
    --test                       Test mode - skip actual SD card write
```