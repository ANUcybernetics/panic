---
id: task-30
title: dietpi-based burn-and-boot script
status: Done
assignee: []
created_date: "2025-07-14"
labels: []
dependencies: []
---

## Description

The current @rpi/ directory is a bit of a mess. I know that I've got the
dietpi-based approach _almost_ working in the past, but it couldn't drive a 4k
display (via X11, at least).

Still, I'd like to give the dietpi approach another go. Here are the priorities:

- use wayland/lightdm with GPU acceleration (and the script can be specialised
  for rpi5 8GB - it doesn't need to support older models)
- auto-detect and use natural display resolution (up to and including 4k) on
  either HDMI port
- allow for configuration of both consumer and enterprise (ssid/user/pass) wifi
- install tailscale and join tailnet automatically based on on auth-key

Many of those features are already implemented in the @rpi/pi-setup.sh script,
and work well.

The overall "north star" is the ability to have a fully automated burn-and-boot
script that can be used to create a new SD card image with all the necessary
configuration and software installed, which (after some initial installation and
reboots) always boots into a full-screen Chromium kiosk-mode window with the
(script provided) kiosk URL.

## Appendix: testing 4K Display Support

### Prerequisites

- Raspberry Pi 5 with 8GB RAM
- 4K-capable HDMI display
- High-quality HDMI 2.1 cable (important for 4K@60Hz)
- SD card with DietPi configured using `pi-setup.sh`

### Initial Setup Verification

1. **Flash the SD card** with the script:

   ```bash
   ./pi-setup.sh \
     --wifi-ssid "YourNetwork" \
     --wifi-password "YourPassword" \
     --tailscale-authkey "tskey-auth-xxxxx" \
     --url "https://webglsamples.org/aquarium/aquarium.html"
   ```

   Note: The WebGL aquarium is a good test for GPU acceleration.

2. **Connect the Pi**:
   - Connect the 4K display to either HDMI port
   - Connect Ethernet for initial setup
   - Insert the SD card and power on

### Verification Steps

#### 1. Check Display Capabilities

After the Pi boots (5-10 minutes), SSH into it:

```bash
# Via Tailscale
tailscale ssh dietpi@panic-rpi

# Or direct IP
ssh dietpi@<pi-ip>
```

Check the display configuration:

```bash
# View logged display info from first boot
sudo cat /var/log/display-capabilities.log

# Check current Wayland outputs
wlr-randr

# Verify GPU acceleration
glxinfo -B | grep -E "OpenGL|renderer"
```

#### 2. Verify Resolution

The output from `wlr-randr` should show something like:

```
HDMI-A-1
  Enabled: yes
  Modes:
    3840x2160@60.000Hz (preferred)
    3840x2160@30.000Hz
    1920x1080@60.000Hz
    ...
  Position: 0,0
  Scale: 1.000000
```

#### 3. Test GPU Performance

View system resource usage while the kiosk is running:

```bash
# Check GPU memory usage
vcgencmd get_mem gpu

# Monitor GPU temperature
watch -n 1 vcgencmd measure_temp

# Check for GPU acceleration in Chromium
sudo journalctl -u wayfire -n 100 | grep -i "gpu\|accel\|gl"
```

#### 4. Visual Tests

The WebGL aquarium should run smoothly at 4K resolution. You can also test with:

- **YouTube 4K videos**: Change URL to a 4K YouTube video
- **WebGL demos**: https://threejs.org/examples/
- **CSS animations**: https://codepen.io/trending

#### 5. Common Issues and Solutions

**Display shows lower resolution than 4K:**

- Check HDMI cable quality (must support HDMI 2.1)
- Try the other HDMI port on the Pi 5
- Verify display supports 4K@60Hz

**Choppy performance:**

```bash
# Check if performance governor is active
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# Should show "performance"

# Check GPU memory split
vcgencmd get_mem gpu
# Should show 512M
```

**Black screen or no display:**

```bash
# Check Wayfire service status
sudo systemctl status wayfire

# View Wayfire logs
sudo journalctl -u wayfire -f

# Restart the display
sudo systemctl restart wayfire
```

### Advanced Configuration

#### Manually Set Resolution

If auto-detection fails, you can force 4K resolution:

1. Edit Wayfire config:

   ```bash
   sudo nano /home/dietpi/.config/wayfire.ini
   ```

2. Update the output section:

   ```ini
   [output:HDMI-A-1]
   mode = 3840x2160@60.000
   position = 0,0
   transform = normal
   scale = 1.0
   ```

3. Restart Wayfire:
   ```bash
   sudo systemctl restart wayfire
   ```

#### Performance Tuning

For optimal 4K performance:

1. **Ensure cooling**: Pi 5 needs good cooling for sustained 4K
2. **Use fast SD card**: Class 10 or better, A2 rating preferred
3. **Limit browser tabs**: Kiosk mode should show single page

### Verification Checklist

- [ ] Pi boots successfully into kiosk mode
- [ ] Display shows native 4K resolution (3840x2160)
- [ ] WebGL content runs smoothly
- [ ] GPU temperature stays below 80°C under load
- [ ] No screen tearing or artifacts
- [ ] Chromium shows hardware acceleration enabled
- [ ] Wayfire compositor running without errors

### Reporting Issues

If 4K display is not working properly:

1. Collect diagnostic info:

   ```bash
   sudo /usr/local/bin/verify-display.sh > display-debug.log 2>&1
   sudo journalctl -u wayfire -n 500 > wayfire.log
   dmesg | grep -i "hdmi\|drm\|gpu" > kernel-display.log
   ```

2. Check for known issues:

   - DietPi forums: https://dietpi.com/forum/
   - Wayfire issues: https://github.com/WayfireWM/wayfire/issues

3. Include in bug reports:
   - Pi model and RAM
   - Display model and capabilities
   - HDMI cable specifications
   - Output from diagnostic commands above
