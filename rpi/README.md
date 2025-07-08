# Raspberry Pi Kiosk Setup

This directory contains scripts to set up Raspberry Pi devices as browser kiosks using DietPi OS. The kiosks boot directly into fullscreen Chromium displaying a specified URL.

## Quick Start

1. Insert an SD card into your Mac
2. Run the automated setup script:

```bash
./automate-pi-setup.sh --url "https://example.com" --wifi-ssid "YourNetwork" --wifi-password "YourPassword" --hostname "kiosk1"
```

3. Insert the SD card into your Pi and power on
4. Wait ~5-10 minutes for initial setup
5. The Pi will boot directly into kiosk mode

## Why DietPi?

We use DietPi instead of Raspberry Pi OS because:
- **Fully automated setup** - No first-boot configuration wizards
- **Minimal footprint** - ~400MB vs 5GB for Raspberry Pi OS
- **Faster boot times** - Optimized for single-purpose use
- **Better automation** - Built-in support for unattended installation

## Features

- ✅ Fully automated setup via SD card
- ✅ Boots directly to kiosk mode (no desktop visible)
- ✅ Supports both regular and enterprise WiFi
- ✅ SSH access with key authentication
- ✅ Tailscale integration for remote access
- ✅ Automatic security updates
- ✅ Mouse cursor auto-hide
- ✅ Screen blanking disabled
- ✅ Cached image downloads for faster subsequent setups

## How It Works

The `automate-pi-setup.sh` script provides a fully automated workflow:

1. **Downloads DietPi image** (with caching for faster subsequent runs)
2. **Writes image to SD card** 
3. **Configures unattended installation** via DietPi's automation system
4. **Sets up WiFi** (including enterprise WPA2-EAP)
5. **Configures kiosk mode** with Chromium
6. **Enables SSH access** with key authentication

The automation uses DietPi's built-in features:

- **dietpi.txt** - Main automation config that specifies software to install, network settings, locale/timezone, and auto-login
- **dietpi-wifi.txt** - WiFi configuration including enterprise support
- **Automation_Custom_Script.sh** - Post-install script that configures Chromium kiosk mode

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

After setup, you can SSH into the Pi:

```bash
# Using the hostname
ssh dietpi@<hostname>.local

# Or with the SSH config entry created by the script
ssh <hostname>
```

The script automatically:
- Generates an SSH key at `~/.ssh/panic_rpi_ssh`
- Installs the public key on the Pi
- Updates your `~/.ssh/config` for easy access

### Tailscale SSH Access

If you provided a Tailscale auth key during setup:

```bash
# SSH from anywhere on your tailnet
ssh dietpi@<hostname>

# No port forwarding or VPN required!
```

To get a Tailscale auth key:
1. Visit https://login.tailscale.com/admin/settings/keys
2. Generate an auth key (consider a reusable key for multiple devices)
3. Use the key with `--tailscale-authkey` during setup

Benefits of Tailscale:
- Access your Pi from anywhere without port forwarding
- Automatic encrypted connections
- Works behind NAT/firewalls
- No manual VPN configuration needed

## Maintenance

### Updating the Display URL

SSH into the Pi and edit the autostart file:
```bash
sudo nano /home/dietpi/.config/openbox/autostart
```

Change the URL in the chromium line and reboot.

### Viewing Logs

```bash
# System logs
sudo journalctl -f

# X session errors
cat /home/dietpi/.xsession-errors
```

### Manual Control

```bash
# Stop kiosk
sudo systemctl stop lightdm

# Start kiosk
sudo systemctl start lightdm

# Restart kiosk
sudo systemctl restart lightdm
```

### Monitoring Setup Progress

To watch the initial setup progress:
1. Connect Pi to screen during first boot
2. You'll see DietPi's automation progress
3. Or SSH in after ~5 minutes and check logs: `sudo journalctl -f`

## Troubleshooting

### SD Card Not Found
- Ensure SD card is inserted in built-in reader
- Script expects SD card at `/dev/disk4` on Mac
- Check with `diskutil list`

### Black Screen
- Check if Chromium is running: `ps aux | grep chromium`
- Check X session errors: `cat ~/.xsession-errors`
- Verify URL is accessible: `curl -I <your-url>`

### WiFi Not Connecting
- Check WiFi config: `sudo nano /boot/dietpi-wifi.txt`
- For enterprise WiFi, ensure phase1="peaplabel=0" is set
- Restart networking: `sudo systemctl restart networking`

### Kiosk Not Starting
- SSH in and check: `sudo systemctl status lightdm`
- View logs: `cat /home/dietpi/.xsession-errors`
- Verify Chromium installed: `which chromium`

### Display Issues
- Adjust GPU memory split: `sudo dietpi-config` > Display Options
- Check HDMI config: `sudo nano /boot/config.txt`

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
- SSH key authentication is configured automatically
- Consider disabling password auth after setup
- DietPi includes automatic security updates

## Hardware Requirements

- Raspberry Pi 3, 4, or 5
- 8GB+ SD card
- Stable power supply
- HDMI display
- Network connection (WiFi or Ethernet)
- macOS with SD card reader (for running the setup script)