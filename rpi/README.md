# Raspberry Pi Kiosk Setup Script

This script automatically configures a Raspberry Pi to run in kiosk mode,
displaying a full-screen web browser pointed at a specified URL.

## Prerequisites

Before running this setup script, you'll need to:

1. **Flash the Raspberry Pi OS** using the separate `rpi-imager` tool
2. **Boot your Pi** and ensure it has network connectivity
3. **Have the target URL** ready that you want to display in kiosk mode

## Usage

Run this command directly on your Raspberry Pi (via SSH or local terminal):

```bash
curl -sSL https://raw.githubusercontent.com/ANUcybernetics/panic/main/rpi/pi-setup.sh | bash -s -- "https://panic.fly.dev"
```

Replace `https://panic.fly.dev` with your desired URL.

## What the script does

- Installs Chromium browser and required packages
- Creates a systemd service that launches Chromium in kiosk mode
- Configures auto-login for the current user
- Sets up the browser to run full-screen with kiosk optimizations
- Enables auto-restart on crashes (checking every 10s)
- Automatically reboots the system to start kiosk mode

## After installation

The Pi will automatically boot into kiosk mode. To manage the service:

```bash
# Check service status
sudo systemctl status kiosk

# View logs
sudo journalctl -u kiosk -f

# Stop/start the service
sudo systemctl stop kiosk
sudo systemctl start kiosk
```

## Changing the kiosk URL

To change the URL that the kiosk displays after installation:

1. **Edit the service file** to update the URL:

   ```bash
   sudo sed -i 's|http://old-url|http://new-url|g' /etc/systemd/system/kiosk.service
   ```

2. **Reload systemd** to pick up the changes:

   ```bash
   sudo systemctl daemon-reload
   ```

3. **Restart the kiosk service**:
   ```bash
   sudo systemctl restart kiosk
   ```

**Example** - Change to a specific panic URL:

```bash
sudo sed -i 's|https://panic.fly.dev|http://panic.fly.dev/i/3/0|g' /etc/systemd/system/kiosk.service
sudo systemctl daemon-reload
sudo systemctl restart kiosk
```
