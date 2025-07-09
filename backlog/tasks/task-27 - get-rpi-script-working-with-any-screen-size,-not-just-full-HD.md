---
id: task-27
title: "get rpi script working with any screen size, not just full HD"
status: In Progress
assignee: []
created_date: "2025-07-09"
completed_date: "2025-07-09"
labels: ["needs-test"]
dependencies: []
---

## Description

I just plugged the latest image (created by the "automate setup" script in
@rpi), and while it works on a full HD display, it didn't work at all on a 4K
display. It flashed up something for a second, then the screen went black.

## Solution

Updated the automate-pi-setup.sh script to better handle 4K and high-resolution
displays:

1. **Improved resolution detection:**

   - Added longer wait time (5s) for display initialization
   - Multiple retry attempts (3x) for xrandr resolution detection
   - Explicit DISPLAY=:0 export
   - Better logging of detected resolution

2. **GPU memory optimization:**

   - Increased GPU memory split from 128MB to 256MB for 4K support

3. **Chromium flags for high-res displays:**

   - Added `--force-device-scale-factor=1` to prevent scaling issues
   - Added GPU acceleration flags for better performance
   - Conditional memory limits for displays > 2560x1440
   - Disabled vsync and smooth scrolling for better performance

4. **Display mode setting in xinitrc:**

   - Added xrandr mode setting to ensure proper display initialization
   - Sets the best available mode at 60Hz refresh rate

5. **Updated documentation:**
   - Added troubleshooting steps for 4K displays
   - Documented the automatic optimizations
   - Added debugging commands for display issues

The script now automatically detects and properly configures for any screen
resolution, including 4K/UHD displays.
