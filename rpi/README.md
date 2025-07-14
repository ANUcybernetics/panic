# Raspberry Pi Kiosk Setup

This directory contains a script to set up Raspberry Pi 5 devices as browser kiosks that boot directly into fullscreen Chromium displaying a specified URL.

## Overview

The `pi-setup.sh` script creates a fully automated DietPi installation that:
- Boots directly into GPU-accelerated kiosk mode using Wayfire/Wayland compositor
- Automatically joins your Tailscale network (no manual IP discovery needed)
- Supports native display resolutions including 4K at 60Hz with full GPU acceleration
- Configures WiFi (both consumer WPA2 and enterprise 802.1X) for subsequent use after initial Ethernet setup
- Hides the mouse cursor and provides a clean kiosk experience
- Optimized specifically for Raspberry Pi 5 with 8GB RAM

## How It Works

DietPi provides a reliable firstboot automation mechanism through `AUTO_SETUP_CUSTOM_SCRIPT_EXEC`:

1. **SD Card Preparation**:
   - Flashes DietPi image (lighter weight than Raspberry Pi OS)
   - Creates `dietpi.txt` with automation settings
   - Configures WiFi credentials for later use
   - Places custom script that runs automatically on first boot

2. **Automatic First Boot** (no manual intervention):
   - DietPi runs the custom script without any user interaction
   - Installs and configures Tailscale with your auth key
   - Sets up Wayfire compositor for GPU-accelerated Wayland
   - Configures Chromium in kiosk mode with native resolution support
   - Reboots into kiosk mode showing your URL

## Prerequisites

1. **Initial setup requires Ethernet connection**
   - The first boot must happen with Ethernet connected
   - WiFi is configured during first boot for subsequent use
   - After initial setup, the Pi can run on WiFi alone

2. **Install required tools on your Mac:**

```bash
# Install jq for JSON handling
brew install jq

# Install pv for progress display
brew install pv
```

3. **Get a Tailscale auth key:**
   - Visit https://login.tailscale.com/admin/settings/keys
   - Generate a reusable auth key
   - Enable "Pre-authorized" for automatic approval

## Setting Up a Kiosk

### Basic Setup

For a kiosk that automatically joins Tailscale:

```bash
# Flash the SD card
./pi-setup.sh \
  --wifi-ssid "YourNetwork" \
  --wifi-password "YourPassword" \
  --tailscale-authkey "tskey-auth-xxxxx" \
  --url "https://panic.fly.dev/"

# Insert SD card into Pi (with Ethernet) and power on
# Wait 5-10 minutes for automatic setup

# Verify it joined Tailscale
tailscale status | grep panic-rpi

# That's it! The Pi is now showing your URL in kiosk mode
```

### Enterprise WiFi Setup

For networks with enterprise authentication:

```bash
./pi-setup.sh \
  --wifi-ssid "CorpNetwork" \
  --wifi-enterprise-user "username@domain.com" \
  --wifi-enterprise-pass "password" \
  --tailscale-authkey "tskey-auth-xxxxx" \
  --url "https://example.com/"
```

### Custom Configuration

All options:

```bash
./pi-setup.sh \
  --url "https://example.com/"          # URL to display
  --hostname "my-kiosk"                  # Hostname (default: panic-rpi)
  --username "admin"                     # Username (default: dietpi)
  --password "securepass"                # Password (default: dietpi)
  --wifi-ssid "Network"                  # WiFi network name
  --wifi-password "pass"                 # WiFi password
  --tailscale-authkey "tskey-..."       # Tailscale auth key
  --ssh-key ~/.ssh/id_rsa.pub          # SSH public key for access
```

## Setting Up Multiple Kiosks

For multiple Pis with different configurations:

1. **Create a device list** (`devices.json`):

```json
[
  {
    "hostname": "panic-display-1",
    "url": "https://panic.fly.dev/installations/display-1"
  },
  {
    "hostname": "panic-display-2",
    "url": "https://panic.fly.dev/installations/display-2"
  },
  {
    "hostname": "panic-kiosk-lobby",
    "url": "https://example.com/lobby-dashboard"
  }
]
```

2. **Deploy each device**:

For each device in your list:
- Run `pi-setup.sh` with the specific hostname and URL
- Flash SD card, insert into Pi, and power on
- Each Pi will automatically join your Tailscale network

## Remote Management

Once deployed, manage your kiosks via Tailscale:

```bash
# SSH into any kiosk
tailscale ssh dietpi@panic-rpi

# Change the displayed URL
echo "https://new-url.com" | sudo tee /boot/firmware/SOFTWARE_CHROMIUM_AUTOSTART_URL
sudo systemctl restart wayfire

# View kiosk logs
sudo journalctl -u wayfire -f

# Reboot a kiosk
sudo reboot

# Check all your kiosks
tailscale status | grep panic
```

## Troubleshooting

**Pi doesn't join Tailscale network:**
- Verify the Pi has Ethernet connectivity during first boot
- Check if Tailscale auth key is still valid
- Connect a monitor to see boot messages

**Display issues:**
- Wayfire automatically detects and uses native resolution
- For 4K displays, ensure HDMI cable supports 4K@60Hz
- Check logs: `sudo journalctl -u wayfire -n 50`

**Wrong URL displayed:**
- Check current URL: `grep SOFTWARE_CHROMIUM_AUTOSTART_URL /boot/firmware/dietpi.txt`
- Update URL and restart: `sudo systemctl restart wayfire`

**Can't SSH to Pi:**
- Ensure Pi is on Tailscale: `tailscale status | grep <hostname>`
- Try direct SSH if on same network: `ssh dietpi@<pi-ip>`

## Script Reference

```bash
./pi-setup.sh [OPTIONS]

Configuration Options:
    --url <url>                  URL to display in kiosk mode (default: https://panic.fly.dev/)
    --hostname <name>            Hostname for the Raspberry Pi (default: panic-rpi)
    --username <user>            Username for the admin account (default: dietpi)
    --password <pass>            Password for the admin account (default: dietpi)

Network Options (at least one required):
    --wifi-ssid <ssid>           WiFi network name
    --wifi-password <pass>       WiFi password (for WPA2-PSK networks)
    --wifi-enterprise-user <u>   Enterprise WiFi username
    --wifi-enterprise-pass <p>   Enterprise WiFi password
    --tailscale-authkey <key>    Tailscale auth key for automatic join

Optional:
    --ssh-key <path>             Path to SSH public key
    --test                       Test mode - skip actual SD card write
```

## Technical Details

### Why DietPi?

- **Lighter weight**: Minimal Debian-based OS optimized for SBCs
- **Reliable automation**: `AUTO_SETUP_CUSTOM_SCRIPT_EXEC` runs consistently
- **Faster boot**: Less overhead than full Raspberry Pi OS
- **Better for kiosks**: Designed for headless and automated deployments
- **Latest version**: Always uses the latest DietPi release with full Raspberry Pi 5 support

### Why Wayfire/Wayland?

- **Native GPU acceleration**: Full hardware acceleration with V3D/VC4 drivers
- **Better 4K support**: Handles 4K@60Hz without X11 limitations
- **Modern stack**: Future-proof compared to X11
- **Auto-detection**: Automatically uses optimal display settings
- **Hardware video decoding**: Supports H.265/HEVC hardware acceleration

### GPU Optimization

The script configures:
- 512MB GPU memory split for 4K displays
- Performance CPU governor for consistent frame rates
- Hardware-accelerated Chromium flags for smooth rendering
- Wayland-native operation avoiding X11 overhead

### Security Notes

- Default credentials: `dietpi` / `dietpi` (change in production!)
- Tailscale provides encrypted remote access
- Consider using SSH keys instead of passwords
- Kiosks run with minimal privileges
- DietPi includes automatic security updates

### Hardware Requirements

- Raspberry Pi 5 with 8GB RAM (script optimized for this model)
- 16GB+ SD card (32GB recommended for better performance)
- Official Raspberry Pi 27W USB-C power supply
- HDMI 2.1 cable for 4K@60Hz support
- 4K-capable display (or any HDMI display)
- Ethernet connection for initial setup
- WiFi for subsequent operation (optional)

### Testing 4K Support

See the task file for detailed instructions on verifying 4K display capabilities.