# Raspberry Pi Kiosk Setup

This directory contains a script to set up Raspberry Pi 5 devices as browser
kiosks that boot directly into fullscreen Chromium displaying a specified URL.

## Overview

The `pi-setup.sh` script creates a fully automated [DietPi](https://dietpi.com)
installation that:

- boots directly into GPU-accelerated kiosk mode using Cage Wayland compositor
- automatically joins your Tailscale network
- supports native display resolutions including 4K at 60Hz
- configures WiFi (WPA2 and enterprise 802.1X)
- includes HDMI audio support
- optimized specifically for Raspberry Pi 5 with 8GB RAM
- provides a `kiosk-set-url` utility for easy URL changes

## Prerequisites

1. **Initial setup requires Ethernet connection** - WiFi is configured during
   first boot for subsequent use

2. **Install required tools on your Mac:**

```bash
brew install jq pv
uv tool install --python 3.12 humanfriendly
```

3. **Get a Tailscale auth key** from
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
```

After flashing, insert the SD card into the Pi (with Ethernet connected) and
power on. The Pi will automatically set up and join your Tailscale network
within 5-10 minutes.

## Remote Management

```bash
# SSH via Tailscale (no password needed if your Tailscale user has access)
tailscale ssh dietpi@<hostname>

# Change kiosk URL
sudo kiosk-set-url                    # View current URL
sudo kiosk-set-url https://new-url.com # Change URL

# View logs and status
sudo journalctl -u cage-kiosk -f      # View kiosk logs
sudo systemctl status cage-kiosk       # Check status
sudo systemctl restart cage-kiosk      # Restart kiosk

# Check all kiosks on Tailscale
tailscale status | grep -E "lobby|conference|kiosk"
```

## Troubleshooting

**Pi doesn't join Tailscale network:**

- verify the Pi has Ethernet connectivity during first boot
- check if Tailscale auth key is still valid
- connect a monitor to see boot messages

**Display issues:**

- cage automatically detects and uses native resolution
- for 4K displays, ensure HDMI cable supports 4K@60Hz
- check logs: `sudo journalctl -u cage-kiosk -n 50`

**Audio not working:**

- check audio setup: `sudo journalctl -u hdmi-audio-setup`
- verify PulseAudio: `pactl info`

**Can't SSH to Pi:**

- ensure Pi is on Tailscale: `tailscale status | grep <hostname>`
- try direct SSH if on same network: `ssh dietpi@<pi-ip>`

## Script Reference

Run `./pi-setup.sh --help` for complete options and examples.
