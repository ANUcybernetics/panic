# Raspberry Pi Kiosk Setup Automation

This directory contains scripts to automate the setup of Raspberry Pi devices in
kiosk mode.

## Scripts Overview

### 1. `pi-setup.sh` - Basic Setup Script

The original setup script that runs on the Pi itself. Can be executed via:

```bash
curl -sSL https://raw.githubusercontent.com/ANUcybernetics/panic/main/rpi/pi-setup.sh | bash -s -- "https://panic.fly.dev"
```

### 2. `automate-pi-setup.sh` - Full Automation Script

Automates the entire process from imaging the SD card to configuration:

- Downloads Raspberry Pi OS (or uses existing image)
- Writes image to SD card using rpi-imager CLI
- Configures WiFi (including enterprise WPA2-EAP/PEAP) and SSH
- Injects first-run script for automatic kiosk setup

Usage:

```bash
# Regular WPA2-PSK WiFi:
./automate-pi-setup.sh --url "https://example.com" --wifi-ssid "MyNetwork" --wifi-password "MyPassword"

# Enterprise WPA2-EAP (PEAP) WiFi:
./automate-pi-setup.sh --url "https://example.com" --wifi-ssid "CorpNetwork" \
    --wifi-enterprise-user "username@domain.com" \
    --wifi-enterprise-pass "password"
```

Options:

- `--image <file>` - Use existing image file (skip download)
- `--url <url>` - Kiosk URL (default: https://panic.fly.dev)
- `--wifi-ssid <ssid>` - WiFi network name
- `--wifi-password <pass>` - WiFi password (for WPA2-PSK)
- `--wifi-enterprise-user <u>` - Enterprise WiFi username (for WPA2-EAP/PEAP)
- `--wifi-enterprise-pass <p>` - Enterprise WiFi password (for WPA2-EAP/PEAP)

## Automation Workflow

### Recommended Method: Direct SD Card Automation

1. Insert SD card into your Mac's card reader
2. Run the automation script:

   ```bash
   # Basic setup with custom hostname and user:
   ./automate-pi-setup.sh \
     --url "https://panic.fly.dev" \
     --wifi-ssid "YourWiFiNetwork" \
     --wifi-password "YourWiFiPassword" \
     --hostname "panic-kiosk" \
     --username "kiosk" \
     --password "securepassword"

   # Enterprise WiFi setup:
   ./automate-pi-setup.sh \
     --url "https://panic.fly.dev" \
     --wifi-ssid "CorpNetwork" \
     --wifi-enterprise-user "username@domain.com" \
     --wifi-enterprise-pass "password" \
     --hostname "panic-display"
   ```

3. The script will:
   - Generate SSH key at `~/.ssh/panic_rpi_ssh` (if not exists)
   - Find your SD card
   - Download latest Raspberry Pi OS (or use provided image)
   - Write the image using rpi-imager
   - Configure the boot partition with:
     - SSH enabled with key authentication
     - Custom username/password
     - Custom hostname
     - WiFi credentials (regular or enterprise)
     - First-run script that installs kiosk mode
   - Update your SSH config for easy access
4. Insert SD card into Pi and power on
5. Pi will automatically:
   - Connect to WiFi
   - Download and run kiosk setup
   - Reboot into kiosk mode

## How It Works

The automation creates a `firstrun.sh` script in the boot partition that:

1. Waits for network connectivity
2. Enables SSH for remote access
3. Downloads and executes the kiosk setup script
4. Configures systemd service for Chromium in kiosk mode
5. Sets up auto-login
6. Reboots into kiosk mode

## SSH Access

After setup, you can SSH into the Pi using passwordless authentication:

```bash
# Using the SSH config entry created by the script:
ssh panic-rpi

# Or directly with the SSH key:
ssh -i ~/.ssh/panic_rpi_ssh <username>@<hostname>.local

# Examples:
ssh -i ~/.ssh/panic_rpi_ssh kiosk@panic-kiosk.local
ssh -i ~/.ssh/panic_rpi_ssh pi@panic-display.local
```

The script automatically:

- Generates an SSH key at `~/.ssh/panic_rpi_ssh`
- Installs the public key on the Pi
- Creates an SSH config entry for easy access

## Monitoring Setup Progress

To watch the setup progress:

1. SSH into the Pi after it boots
2. Check the systemd journal:
   ```bash
   sudo journalctl -f
   ```

## Troubleshooting

### SD Card Not Found

- Ensure SD card is properly inserted
- Check with `diskutil list external`
- May need to format card first if corrupted

### WiFi Not Connecting

- Verify SSID and password are correct
- Check if network uses special authentication
- Can configure manually via SSH over Ethernet

### Kiosk Not Starting

- SSH in and check service status:
  ```bash
  sudo systemctl status kiosk
  sudo journalctl -u kiosk -f
  ```

## Security Notes

- Change default Pi password immediately after setup
- Consider disabling password auth for SSH
- Use strong WiFi passwords
- Keep the kiosk URL private if sensitive

## Requirements

- macOS with Raspberry Pi Imager installed
- SD card (8GB minimum recommended)
- SD card reader
