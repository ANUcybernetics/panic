---
id: task-34
title: Fix color banding on panic-tv1-1 display
status: To Do
assignee: []
created_date: '2025-08-01'
labels: []
dependencies: []
---

## Description

Investigate and resolve severe color banding/dithering artifacts on Raspberry Pi 5 display

## Problem Details

The Raspberry Pi 5 (panic-tv1-1) is displaying severe color banding that looks like 256-color mode despite the system reporting 24-bit color support. Gradients show visible stepping/dithering artifacts instead of smooth transitions.

## Current Status

### Working:
- Display resolution: 3840x2160 @ 60Hz ✅
- Cage Wayland compositor running
- Chromium kiosk mode operational  
- GPU drivers loaded (vc4/v3d)

### Issue:
- Severe color banding (looks like 8-bit/256 colors)
- DRM subsystem shows: `color-range=YCbCr limited range`
- Despite framebuffer reporting 24-bit support (`format=XR24`)
- System reports 16 bits per pixel at `/sys/class/graphics/fb0/bits_per_pixel`

## Investigation Summary

### Attempted Fixes

1. **Config.txt modifications:**
   - `framebuffer_depth=24`
   - `framebuffer_ignore_alpha=1`
   - `max_framebuffer_depth=24`
   - `hdmi_pixel_encoding=2` (force RGB)
   - `hdmi_force_rgb_range=2` (force full range)
   - `hdmi_enable_4kp60=1`
   - `max_pixel_freq=600`

2. **Kernel parameters:**
   - `video=HDMI-A-1:3840x2160@60D,rgb,colorspace=1`

3. **Driver configuration:**
   - `/etc/modprobe.d/vc4.conf`: `options vc4 force_rgb888=1 force_rgb_range=2`

4. **Chromium flags tested:**
   - Removed `--force-color-profile=srgb`
   - Tried `--use-gl=egl` instead of `--use-gl=angle`
   - Tested with `--disable-gpu-compositing`

### Root Cause Analysis

The display pipeline is stuck in YCbCr limited range mode despite configuration attempts. This appears to be either:

1. **Driver limitation**: VC4/V3D drivers on RPi 5 may not fully support RGB full range output
2. **EDID negotiation**: TV may be incorrectly reporting capabilities
3. **Wayland/Cage limitation**: The compositor may be forcing limited color mode
4. **HDMI bandwidth**: Despite 4K@60Hz working, color depth may be limited by bandwidth

### Technical Findings

- Early boot framebuffer shows correct 24-bit: `format=r8g8b8, mode=1920x1080x24`
- After VC4 driver loads, limited to 16-bit with YCbCr limited range
- RPi 5 doesn't support traditional `gpu_mem` or many `vcgencmd` HDMI commands
- DRM debug shows all planes using `color-encoding=ITU-R BT.709 YCbCr` with `color-range=YCbCr limited range`

## Next Steps to Try

1. **Alternative display stack:**
   - Try X11 instead of Wayland (install lightdm + openbox)
   - Test with different compositor (weston, sway)

2. **Alternative browsers:**
   - Firefox with native Wayland support
   - Electron-based kiosk app

3. **Force EDID:**
   - Create custom EDID file forcing RGB 4:4:4
   - Use `drm.edid_firmware` to override TV EDID

4. **Lower resolution test:**
   - Test at 1080p to see if color depth improves
   - May indicate HDMI bandwidth limitation

5. **Direct framebuffer test:**
   - Write test pattern directly to `/dev/fb0`
   - Bypasses entire graphics stack to isolate issue

## Workaround Considerations

If hardware/driver limitation:
- Design UI with limited gradients
- Use solid colors and high contrast
- Avoid subtle color transitions

## Impact

Visual quality is significantly degraded with visible color banding. This affects the aesthetic quality of the display but doesn't impact functionality.
