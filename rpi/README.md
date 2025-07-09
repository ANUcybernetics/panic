# Raspberry Pi Kiosk Setup

This directory contains scripts to set up Raspberry Pi devices as browser kiosks
using DietPi OS. The kiosks boot directly into fullscreen Chromium displaying a
specified URL.

## Quick Start

1. Insert an SD card into your Mac's built-in SD card reader
2. Run the automated setup script:

```bash
./automate-pi-setup.sh --url "https://example.com" --wifi-ssid "YourNetwork" --wifi-password "YourPassword" --hostname "kiosk1"
```

3. Insert the SD card into your Pi and power on
4. Wait ~10-15 minutes for initial setup (first boot takes longer)
5. The Pi will boot directly into kiosk mode at full screen resolution

## Why DietPi?

We use DietPi instead of Raspberry Pi OS because:

- **Fully automated setup** - No first-boot configuration wizards
- **Minimal footprint** - ~400MB vs 5GB for Raspberry Pi OS
- **Faster boot times** - Optimized for single-purpose use
- **Better automation** - Built-in support for unattended installation

## Features

- ✅ Fully automated setup via SD card
- ✅ Boots directly to kiosk mode (no desktop visible)
- ✅ Auto-detects native display resolution
- ✅ Supports both regular and enterprise WiFi
- ✅ SSH server pre-installed for remote access
- ✅ Tailscale integration for secure remote access
- ✅ Mouse cursor auto-hide with unclutter
- ✅ Screen blanking disabled
- ✅ Easy URL changes with `kiosk-url` command
- ✅ Comprehensive kiosk flags (no pinch, no navigation, etc.)
- ✅ Cached image downloads for faster subsequent setups

## How It Works

The `automate-pi-setup.sh` script provides a fully automated workflow:

1. **Downloads DietPi image** (with caching for faster subsequent runs)
2. **Writes image to SD card**
3. **Configures unattended installation** via DietPi's automation system
4. **Sets up WiFi** (including enterprise WPA2-EAP)
5. **Configures kiosk mode** with Chromium

The automation uses DietPi's built-in features:

- **dietpi.txt** - Main automation config that specifies software to install,
  network settings, locale/timezone, and auto-login
- **dietpi-wifi.txt** - WiFi configuration including enterprise support
- **Automation_Custom_Script.sh** - Post-install script that configures Chromium
  kiosk mode

## Script Options

### `automate-pi-setup.sh`

**Options:**

- `--url <url>` - The URL to display in kiosk mode (required)
- `--wifi-ssid <ssid>` - WiFi network name
- `--wifi-password <pass>` - WiFi password (for WPA2-PSK)
- `--wifi-enterprise-user <user>` - Enterprise WiFi username
- `--wifi-enterprise-pass <pass>` - Enterprise WiFi password
- `--hostname <name>` - Device hostname (default: DietPi)
- `--password <pass>` - Password for dietpi user (default: dietpi)
- `--tailscale-authkey <key>` - Tailscale auth key for automatic network join
- `--list-cache` - Show cached images
- `--clear-cache` - Clear cached images

### Configuration Examples

**Regular home/office WiFi:**

```bash
./automate-pi-setup.sh \
  --url "https://panic.fly.dev" \
  --wifi-ssid "MyNetwork" \
  --wifi-password "MyPassword" \
  --hostname "panic-kiosk"
```

**Enterprise WiFi (WPA2-EAP/PEAP):**

```bash
./automate-pi-setup.sh \
  --url "https://panic.fly.dev/display/1" \
  --wifi-ssid "CorpNetwork" \
  --wifi-enterprise-user "username@domain.com" \
  --wifi-enterprise-pass "password" \
  --hostname "display1"
```

**Ethernet Only:**

```bash
./automate-pi-setup.sh \
  --url "https://example.com" \
  --hostname "wired-kiosk"
```

**Multiple Displays:**

```bash
for i in {1..5}; do
  ./automate-pi-setup.sh \
    --url "https://panic.fly.dev/i/$i/grid" \
    --hostname "panic$i" \
    --wifi-ssid "ANU-Secure" \
    --wifi-enterprise-user "SOCY2" \
    --wifi-enterprise-pass "pass"
done
```

**With Tailscale for Remote Access:**

```bash
./automate-pi-setup.sh \
  --url "https://panic.fly.dev" \
  --wifi-ssid "MyNetwork" \
  --wifi-password "MyPassword" \
  --hostname "panic-kiosk" \
  --tailscale-authkey "tskey-auth-xxxxx"
```

## SSH Access

SSH server (OpenSSH) is automatically installed on all kiosks for remote
management.

### Tailscale SSH Access (Recommended)

If you provided a Tailscale auth key during setup, you can SSH into the Pi from
anywhere on your tailnet:

```bash
# SSH from anywhere on your tailnet
ssh dietpi@<hostname>

# No port forwarding or VPN required!
```

**Important:** You must configure Tailscale ACLs to allow SSH access:

1. Visit https://login.tailscale.com/admin/acls
2. Add SSH rules to your policy:

```json
{
  "acls": [
    // ... existing rules ...
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["your-email@domain.com"],
      "dst": ["tag:your-tag"], // or specific hostnames
      "users": ["dietpi", "root"]
    }
  ]
}
```

### Local Network Access

Without Tailscale, use standard SSH with password authentication:

```bash
# Using the IP address
ssh dietpi@<ip-address>

# Or using mDNS hostname (may require .local suffix)
ssh dietpi@<hostname>.local

# Default password: dietpi (or what you specified with --password)
```

### Getting a Tailscale Auth Key

1. Visit https://login.tailscale.com/admin/settings/keys
2. Generate an auth key (use reusable + pre-authorized for multiple devices)
3. Optionally tag devices for easier ACL management
4. Use the key with `--tailscale-authkey` during setup

Benefits of Tailscale:

- Access your Pi from anywhere without port forwarding
- Automatic encrypted connections
- Works behind NAT/firewalls
- No manual VPN configuration needed
- Centralized access control via ACLs

## Maintenance

### Updating the Display URL

The easiest way to change the kiosk URL is using the built-in `kiosk-url`
command:

```bash
# Check current URL
ssh dietpi@<hostname> kiosk-url

# Change to a new URL
ssh dietpi@<hostname> kiosk-url https://new-url.com

# Or interactively after SSH:
ssh dietpi@<hostname>
kiosk-url https://new-url.com
```

The URL change takes effect immediately - no reboot required!

### Viewing Logs

```bash
# System logs
sudo journalctl -f

# Chromium/kiosk specific logs
sudo journalctl -u getty@tty1 -f

# DietPi automation logs (useful for troubleshooting setup)
cat /var/tmp/dietpi/logs/dietpi-automation_custom_script.log
```

### Manual Control

```bash
# Restart kiosk (chromium)
sudo systemctl restart getty@tty1

# Stop kiosk temporarily
sudo killall chromium

# View kiosk service status
sudo systemctl status getty@tty1

# Reboot the Pi
sudo reboot
```

### Monitoring Setup Progress

To watch the initial setup progress:

1. Connect Pi to screen during first boot
2. You'll see DietPi's automation progress
3. Or SSH in after ~5 minutes and check logs: `sudo journalctl -f`

## Troubleshooting

### SD Card Not Found

- Ensure SD card is inserted in Mac's built-in SD card reader
- Script automatically finds the SD card reader (no longer hardcoded)
- Check with `diskutil list` to see all disks
- Look for "Built In SDXC Reader" in disk info

### Black Screen / No Display

- Check if Chromium is running: `ps aux | grep chromium`
- Check current resolution: `ps aux | grep -oE "window-size=[0-9]+,[0-9]+"`
- Verify URL is accessible: `curl -I <your-url>`
- View logs: `sudo journalctl -u getty@tty1 -n 50`

### Wrong Resolution

- The script auto-detects native resolution
- Check detected resolution in process list: `ps aux | grep window-size`
- Force a specific resolution by editing `/boot/dietpi.txt`:
  ```bash
  SOFTWARE_CHROMIUM_RES_X=1920
  SOFTWARE_CHROMIUM_RES_Y=1080
  ```
- Then restart: `sudo systemctl restart getty@tty1`

### Mouse Cursor Visible

- Check if unclutter is running: `ps aux | grep unclutter`
- Manually hide cursor: `DISPLAY=:0 unclutter -idle 0.1 -root &`

### WiFi Not Connecting

- Check WiFi config: `sudo nano /boot/dietpi-wifi.txt`
- For enterprise WiFi, verify all PEAP settings are correct
- View network status: `ip addr` and `iwconfig`
- Check logs: `sudo journalctl -u networking -n 50`

### SSH Access Issues

- Verify SSH is running: `sudo systemctl status ssh`
- For Tailscale SSH, check ACL configuration
- For local SSH, ensure you're on the same network
- Default credentials: username `dietpi`, password as set during setup

### Kiosk Not Starting After Boot

- Check service status: `sudo systemctl status getty@tty1`
- Verify autostart mode: `cat /boot/dietpi/.dietpi-autostart_index` (should
  be 11)
- Check if X server started: `ps aux | grep xinit`
- Verify Chromium installed: `which chromium`

## Advanced Usage

### Custom DietPi Configuration

Edit the `dietpi.txt` section in the script to customize:

- Different software packages
- Alternative desktop environments
- Network settings
- Performance tuning

## Cache Management

The script caches downloaded images for 30 days:

```bash
# List cached images
./automate-pi-setup.sh --list-cache

# Clear cache
./automate-pi-setup.sh --clear-cache
```

Images are stored in `~/.cache/dietpi-images/`

## Security Notes

- Default user is `dietpi` (not changeable via automation)
- Set a strong password with `--password`
- With Tailscale, SSH is secured through the tailnet
- Without Tailscale, password authentication is used
- DietPi includes automatic security updates

## Hardware Requirements

- Raspberry Pi 3, 4, or 5
- 8GB+ SD card
- Stable power supply
- HDMI display
- Network connection (WiFi or Ethernet)
- macOS with SD card reader (for running the setup script)
