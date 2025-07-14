---
id: task-30
title: dietpi-based burn-and-boot script
status: To Do
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
