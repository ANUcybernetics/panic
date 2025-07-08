---
id: task-1
title: get dietpi script fully working
status: To Do
assignee: []
created_date: "2025-07-08"
labels:
  - devops
dependencies: []
---

## Description

the @rpi/automate-pi-setup.sh script successfully:

1. creates an image, which boots and downloads a bunch of updates
2. connects to the wifi (based on the script-provided wifi credentials)
3. after updating, boots into a Chromium browser in kiosk mode

However, that browser window

- doesn't load the correct page (instead, it loads the dietpi homepage)
- only occupies the top left-hand corner of the display (it _looks_ to be about
  1280x720, but I can't tell exactly), while the rest of the screen is
  completely black

If I close the browser window (with alt + F4) then the text terminal that I see
_is_ full-screen on the display.
