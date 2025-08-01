---
id: task-35
title: switch back to raspbian bookworm and rpi-imager for pi-setup.sh
status: To Do
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
