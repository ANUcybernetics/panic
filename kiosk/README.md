# Raspberry Pi 5 Kiosk Mode Setup

This directory contains a script that uses the official Raspberry Pi Imager CLI
to automatically configure and burn a Raspberry Pi 5 image for kiosk mode
operation. The resulting SD card will boot straight into a full-screen Chromium
browser displaying a specified URL, with no user interaction required. The
script leverages rpi-imager's built-in configuration capabilities for reliable,
automated setup.

## Features

- **rpi-imager Integration**: Uses official Raspberry Pi Imager CLI for reliable
  setup
- **JSON Configuration**: Modern configuration approach using rpi-imager's JSON
  format
- **Automated Setup**: No manual image mounting or modification required
- **Kiosk Mode**: Boots directly to full-screen Chromium browser with crash
  recovery
- **Audio Support**: Configured to play audio content with proper output routing
- **Enterprise WiFi Support**: Supports enterprise WiFi with PEAP/MSCHAPV2
  authentication
- **Enhanced Monitoring**: Built-in Chromium restart and network connectivity
  monitoring
- **macOS Compatible**: Designed for macOS with automatic SD card detection

## Requirements

### Hardware

- Raspberry Pi 5
- MicroSD card (16GB+ recommended)
- Mac with SDXC Reader slot
- Monitor with HDMI connection
- Power supply for Pi 5

### Software Dependencies

- macOS (tested on recent versions)
- **Raspberry Pi Imager**: Download from
  [raspberrypi.com/software](https://www.raspberrypi.com/software/)
- Command line tools: `diskutil` (included with macOS)
- No additional tools required - rpi-imager handles image download and
  configuration

## Quick Start

```bash
cd kiosk/
chmod +x setup-kiosk.sh
./setup-kiosk.sh <kiosk-url> <wifi-ssid> <wifi-username> <wifi-password>
```

Example:

```bash
./setup-kiosk.sh https://cybernetics.anu.edu.au MyWiFiNetwork myusername mypassword
```

The script requires all four arguments:

- **kiosk-url**: The URL to display in the browser
- **wifi-ssid**: Enterprise WiFi network name
- **wifi-username**: Enterprise WiFi username
- **wifi-password**: Enterprise WiFi password

## Process Overview

The setup script performs these steps:

1. **Create Configuration**: Generates JSON configuration for rpi-imager with:
   - SSH access enabled
   - User account setup (username: `kiosk`, password: `raspberry`)
   - Enterprise WiFi credentials (PEAP/MSCHAPV2)
   - Hostname configuration
2. **Create First-Run Script**: Generates comprehensive setup script for:
   - Package installation (Chromium, OpenBox, etc.)
   - Kiosk mode configuration with auto-restart
   - Audio system setup
   - Boot optimization
3. **Detect SD Card**: Automatically finds removable SD card
4. **Configure & Burn**: Uses rpi-imager CLI to:
   - Download latest Raspberry Pi OS Lite
   - Apply configuration
   - Install first-run script
   - Write everything to SD card in one step
5. **Eject**: Safely ejects the configured SD card

## Configuration Details

### Default Settings

- **Hostname**: `pi-kiosk.local`
- **Username**: `kiosk`
- **Password**: `raspberry`
- **SSH**: Enabled
- **Bluetooth**: Disabled (for faster boot)
- **Boot**: Auto-login to graphical desktop, then launch kiosk mode
- **Audio**: Configured for headphone jack output
- **Network**: Enterprise WiFi with automatic reconnection

### Kiosk Mode Features

- Full-screen Chromium browser with enhanced flags
- No browser UI elements (toolbars, etc.)
- Disabled screensaver and power management
- Audio playback enabled with automatic output routing
- Automatic cursor hiding after 1 second
- Crash recovery and automatic Chromium restart
- Network connectivity monitoring
- No user interaction required
- Enterprise WiFi authentication (PEAP/MSCHAPV2)
- Comprehensive logging at `/var/log/kiosk-setup.log`

## Troubleshooting

### Common Issues

**SD Card Not Found**

```
[ERROR] No SD card found
```

- Ensure SD card is properly inserted
- Try reinserting the card
- Check that the card isn't write-protected
- Script now detects any removable media, not just SDXC readers

**Permission Denied**

```
Permission denied when writing to SD card
```

- The script will prompt for sudo password when needed
- Ensure you have admin privileges

**Network Issues**

```
Pi not connecting to WiFi
```

- Double-check enterprise WiFi credentials (SSID, username, password)
- Ensure the enterprise network supports PEAP authentication
- Verify the network allows device registration
- Try connecting via Ethernet initially for troubleshooting

**Kiosk Not Starting**

```
Pi boots to desktop instead of kiosk mode
```

- Check that the first-run setup completed successfully
- SSH to the Pi and check logs: `cat /var/log/kiosk-setup.log`
- Verify Chromium is running: `pgrep -f chromium-browser`
- Check if the autostart script exists: `ls -la ~/.config/openbox/autostart`
- The setup may take 5-10 minutes on first boot

### Manual Configuration

If automatic setup fails, you can manually configure the Pi:

1. **SSH to the Pi**:

   ```bash
   ssh kiosk@pi-kiosk.local
   ```

2. **Install required packages**:

   ```bash
   sudo apt update
   sudo apt install -y chromium-browser openbox lightdm unclutter
   ```

3. **Configure auto-login**:

   ```bash
   sudo sed -i 's/#autologin-user=/autologin-user=kiosk/' /etc/lightdm/lightdm.conf
   ```

4. **Create kiosk startup script**:
   ```bash
   mkdir -p ~/.config/openbox
   cat > ~/.config/openbox/autostart << 'EOF'
   xset s off
   xset -dpms
   xset s noblank
   unclutter -idle 1 &
   chromium-browser --kiosk --noerrdialogs --disable-infobars --no-first-run --enable-features=OverlayScrollbar --disable-translate --no-default-browser-check --disable-extensions --disable-plugins --incognito --disable-dev-shm-usage "YOUR_URL_HERE" &
   EOF
   chmod +x ~/.config/openbox/autostart
   ```

## File Structure

```
kiosk/
├── README.md           # This file
├── setup-kiosk.sh      # Main setup script using rpi-imager
└── work/               # Created during setup (temporary files, auto-cleaned)
    ├── config.json     # rpi-imager configuration
    └── firstrun.sh     # First-boot setup script

# rpi-imager handles image caching automatically in:
# ~/Library/Caches/Raspberry Pi/
```

## Advanced Usage

### Custom Chromium Flags

Edit the firstrun.sh script generation in setup-kiosk.sh to add custom Chromium
flags:

```bash
# In create_firstrun_script() function, modify the chromium-browser line:
chromium-browser --kiosk --your-custom-flags "\$url" &
```

### Multiple URL Rotation

To rotate between multiple URLs, create a custom script:

```bash
# Create ~/rotate-urls.sh on the Pi
#!/bin/bash
URLS=("https://site1.com" "https://site2.com" "https://site3.com")
while true; do
    for url in "${URLS[@]}"; do
        xdotool search --name "Chromium" key ctrl+l
        sleep 0.5
        xdotool type "$url"
        xdotool key Return
        sleep 30
    done
done
```

### Development Mode

For local development, use a localhost URL and set up port forwarding:

```bash
# Setup with local URL
./setup-kiosk.sh http://localhost:3000 MyWiFi myuser mypass

# Then forward port from your development machine
ssh -L 3000:localhost:3000 kiosk@pi-kiosk.local
```

## Support

For issues specific to this setup script, check:

1. Script logs during execution (verbose output)
2. Pi setup logs: `cat /var/log/kiosk-setup.log` (on the Pi)
3. Pi system logs: `journalctl -f`
4. Chromium process status: `pgrep -f chromium-browser`
5. Network connectivity: `ping 8.8.8.8`

For general Raspberry Pi kiosk mode questions, refer to:

- [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/)
- [Raspberry Pi Forums](https://www.raspberrypi.org/forums/)

## License

This project is provided as-is for educational and personal use.
