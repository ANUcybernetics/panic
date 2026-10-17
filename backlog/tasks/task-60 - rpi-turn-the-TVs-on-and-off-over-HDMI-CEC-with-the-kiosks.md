---
id: TASK-60
title: 'rpi: turn the TVs on and off over HDMI-CEC with the kiosks'
status: To Do
assignee: []
created_date: '2026-10-17 02:51'
labels:
  - rpi
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Each kiosk holds a LiveView websocket open, so the Fly machine can't autostop while any kiosk browser runs. rpi/kiosk.sh start/stop already controls the browsers; the TVs have to be switched by hand. If the Pis can also switch the TVs (and ideally sense their power state), managing the installation gets simpler and the machine can sleep whenever the displays are off.

Remote test on 2026-10-16: all four Pis have /dev/cec0 and cec-ctl, and the TVs show up as physical address 1.0.0.0, but GIVE_DEVICE_POWER_STATUS to the TV (logical address 0) was NACK'd on every Pi. That means either the TVs were off or in deep standby, or CEC is disabled in the TV menus (Anynet+, Bravia Sync, SimpLink, etc.). Needs checking on site.

Test commands (on a Pi; --clear afterwards to release the logical address):
  cec-ctl -d0 --playback
  cec-ctl -d0 --to 0 --give-device-power-status
  cec-ctl -d0 --to 0 --image-view-on   # power on
  cec-ctl -d0 --to 0 --standby         # power off
  cec-ctl -d0 --clear

HDMI hotplug status is no use for sensing: it reports connected whatever the TV's state, because the TV's EDID chip is powered by the Pi's 5V.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 On site, with CEC enabled in each TV's menu, each TV's response to a power-status query is recorded for both on and standby, and whether it obeys image-view-on and standby commands
- [ ] #2 kiosk.sh start powers the TVs on and starts the kiosk browsers; kiosk.sh stop stops the browsers and puts the TVs into standby
- [ ] #3 kiosk.sh status reports each TV's power state alongside the browser state
- [ ] #4 A TV that doesn't respond to CEC doesn't stop the kiosk on that Pi from starting or stopping
- [ ] #5 rpi/README.md documents the CEC setting each TV needs
<!-- AC:END -->
