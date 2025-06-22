# Raspberry Pi 5 Kiosk Mode Setup

This directory contains a script to automatically download, configure, and burn
a Raspberry Pi 5 image for kiosk mode operation. The resulting SD card will boot
straight into a full-screen Chromium browser displaying a specified URL, with no
user interaction required. Downloaded images are cached for reuse.

## Features

- **Automated Setup**: Downloads latest Raspberry Pi OS Lite and configures it
  automatically
- **Kiosk Mode**: Boots directly to full-screen Chromium browser
- **Audio Support**: Configured to play audio content
- **Enterprise WiFi Support**: Supports enterprise WiFi with username/password
  authentication
- **macOS Compatible**: Designed for macOS with SDXC Reader

## Requirements

### Hardware

- Raspberry Pi 5
- MicroSD card (16GB+ recommended)
- Mac with SDXC Reader slot
- Monitor with HDMI connection
- Power supply for Pi 5

### Software Dependencies

- macOS (tested on recent versions)
- Command line tools: `curl`, `diskutil`, `hdiutil`
- Optional: `pv` (for progress display) - install with `brew install pv`
- Optional: `fuse-ext2` (for advanced configuration) - install with
  `brew install fuse-ext2`

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

1. **Download**: Gets the latest Raspberry Pi OS Lite image (cached in
   `~/.raspios-images/`)
2. **Extract**: Decompresses the image file
3. **Mount**: Mounts boot and root partitions for modification
4. **Configure**:
   - Enables SSH access
   - Sets up user account (username: `kiosk`, password: `raspberry`)
   - Configures enterprise WiFi
   - Disables Bluetooth
   - Sets up kiosk mode autostart
5. **Unmount**: Safely unmounts the modified image
6. **Burn**: Writes the configured image to SD card
7. **Eject**: Safely ejects the SD card

## Configuration Details

### Default Settings

- **Hostname**: `pi-kiosk.local`
- **Username**: `kiosk`
- **Password**: `raspberry`
- **SSH**: Enabled
- **Bluetooth**: Disabled
- **Boot**: Direct to kiosk mode (no desktop)

### Kiosk Mode Features

- Full-screen Chromium browser
- No browser UI elements (toolbars, etc.)
- Disabled screensaver and power management
- Audio playback enabled
- Automatic cursor hiding
- No user interaction required
- Enterprise WiFi authentication (PEAP/MSCHAPV2)

## Troubleshooting

### Common Issues

**SD Card Not Found**

```
[ERROR] No SD card found in SDXC Reader
```

- Ensure SD card is properly inserted
- Try reinserting the card
- Check that the card isn't write-protected

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

- Check that the setup completed successfully
- SSH to the Pi and run: `systemctl status kiosk-setup.service`
- Check logs: `journalctl -u kiosk-setup.service`

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
├── setup-kiosk.sh      # Main setup script
├── test-setup.sh       # Test script for validation
└── work/               # Created during setup (temporary files)
    ├── 2025-05-13-raspios-bookworm-arm64-lite.img.xz    # Downloaded image
    ├── raspios-bookworm-arm64-lite.img                  # Extracted image
    ├── boot/           # Mounted boot partition
    └── root/           # Mounted root partition

~/.raspios-images/      # Cached images (created automatically)
└── 2025-05-13-raspios-bookworm-arm64-lite.img.xz
```

## Advanced Usage

### Custom Chromium Flags

Edit the setup script to add custom Chromium flags:

```bash
# In configure_image() function, modify the chromium-browser line:
chromium-browser --kiosk --your-custom-flags "${KIOSK_URL}"
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

1. Script logs during execution
2. Pi system logs: `journalctl -f`
3. Kiosk service logs: `journalctl -u kiosk-setup.service`

For general Raspberry Pi kiosk mode questions, refer to:

- [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/)
- [Raspberry Pi Forums](https://www.raspberrypi.org/forums/)

## License

This project is provided as-is for educational and personal use.
