---
id: task-1
title: get dietpi script fully working
status: Done
assignee: []
created_date: "2025-07-08"
labels:
  - devops
  - awaiting hardware test
dependencies: ["task-30"]
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

## Requirements

- The solution must work with different native display resolutions automatically
- Do not hardcode display resolutions
- Must detect and use the actual connected display's native resolution

## Progress

### Fixed Issues:

1. **URL not loading**: Changed from using `\$KIOSK_URL` variable to directly
   embedding `$url` in the chromium command
2. **Display resolution**: Added dynamic resolution detection using xrandr to
   get native display resolution
   - Extracts actual display dimensions from connected display
   - Falls back to 1920x1080 only if detection fails
   - Uses detected resolution for both --window-size and fullscreen mode

### Changes Made:

- Modified `/home/dietpi/.config/openbox/autostart` generation in the custom
  script
- Added xrandr resolution detection before launching Chromium
- Updated Chromium launch parameters to use detected native resolution
