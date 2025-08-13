---
id: task-35
title: switch back to raspbian bookworm and rpi-imager for pi-setup.sh
status: Done
assignee: []
created_date: "2025-08-01"
labels: []
dependencies: []
---

## Description

The current @rpi/pi-setup.sh script uses DietPi to create a base image that (on
first boot) sets up the various systemd & other config files to run in kiosk
mode and configures the rpi to subsequently boot straight into a fullscreen
Chromium kiosk. See @rpi/README.md for details.

However, the minimal Dietpi + Wayland + Cage approach doesn't work properly -
even with much fiddling there are colorspace issues, etc.

We need to switch back to the standard, latest Raspbian Bookworm image. However,
it still needs to set up all the stuff the current script does (wifi, tailscale,
systemd units) for a full no-user-input burn-and-boot experience.

This sd-card flashing procedure can be linux (ubuntu) specific, and I'm open to
using either the now official `rpi-imager` tool or something like sdm
(https://github.com/gitbls/sdm). It needs to work with the very latest raspbian
OS, and not use any deprecated functionality.

## Progress

### Completed

- Created new `pi-setup.sh.new` script that uses Raspberry Pi OS Bookworm
  instead of DietPi
- Implemented automated configuration using firstrun.sh mechanism
- Switched from Cage to Wayfire compositor for better compatibility
- Added support for both regular and enterprise WiFi configuration
- Implemented NetworkManager-based WiFi setup (replacing deprecated
  wpa_supplicant method)
- Added Tailscale and SSH key configuration
- Created comprehensive kiosk setup with systemd service
- Added `kiosk-set-url` utility for post-installation URL changes
- Updated script for Linux (Ubuntu) compatibility
- Tested script with --test flag to verify configuration generation
- Created updated README.md.new with new instructions

### Implementation Details

- Uses official Raspberry Pi OS Bookworm 64-bit image
- Configures system via boot partition files:
  - `userconf.txt` for user account setup
  - `ssh` file to enable SSH
  - `firstrun.sh` for automated configuration
  - `kiosk-config.json` for passing configuration parameters
- Modifies `cmdline.txt` to run firstrun.sh on first boot
- Installs Wayfire compositor with Wayland support
- Configures Chromium with hardware acceleration flags
- Sets up systemd service for automatic kiosk startup

### Files Created

- `/home/ben/Code/panic/rpi/pi-setup.sh.new` - New setup script
- `/home/ben/Code/panic/rpi/README.md.new` - Updated documentation

### Next Steps

- Test the script with an actual SD card and Raspberry Pi 5
- Verify WiFi connectivity and Tailscale integration
- Confirm kiosk mode starts correctly with proper GPU acceleration
- Replace old files with new versions after successful testing
