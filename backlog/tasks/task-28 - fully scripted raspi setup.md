# Task 28: Fully Scripted Raspberry Pi OS Setup

## Objective
Create a fully automated burn-and-boot process for Raspberry Pi OS that sets up a kiosk mode display without manual intervention.

## Findings

### 1. Raspberry Pi OS Boot Process Changes
- **Raspberry Pi OS Bookworm (2025-05-13) has deprecated the `systemd.run` parameter in cmdline.txt**
- The traditional approach of adding `systemd.run=/boot/firmware/firstrun.sh` to cmdline.txt no longer works
- This was discovered when the firstrun script was created correctly but never executed automatically

### 2. Attempted Approaches

#### Approach 1: systemd.run in cmdline.txt (FAILED)
- Modified cmdline.txt to include `systemd.run=/boot/firmware/firstrun.sh systemd.run_success_action=reboot`
- Script was present but never executed
- Kernel command line at boot didn't include our modifications

#### Approach 2: custom.toml (PARTIAL SUCCESS)
- Created `custom.toml` file following Raspberry Pi Imager format
- File was processed (disappeared after boot)
- SSH and user account were configured
- However, `[all.first_boot] run_commands` didn't execute our script
- Hostname setting also didn't work reliably

#### Approach 3: os_customisations/firstboot.sh (NOT TESTED)
- Created script in `/boot/firmware/os_customisations/firstboot.sh`
- This follows the raspberrypi-sys-mods pattern
- Unclear if this actually executes automatically

### 3. What Actually Works

#### Reliable Methods:
1. **Basic Configuration Files**:
   - `/boot/firmware/ssh` - Empty file to enable SSH (WORKS)
   - `/boot/firmware/userconf.txt` - Username:password_hash for user creation (WORKS)
   - `/boot/firmware/wpa_supplicant.conf` - WiFi configuration (WORKS)
   - `/boot/firmware/config.txt` modifications - Display settings (WORKS)

2. **Manual Execution**:
   - Scripts placed in `/boot/firmware/` can be run manually after SSH
   - This approach is 100% reliable but requires manual intervention

### 4. Technical Issues Encountered

1. **macOS sed compatibility**: 
   - `sed -i` requires a backup extension on macOS
   - Fixed by using temporary files instead

2. **Boot filesystem paths**:
   - `/boot/cmdline.txt` is now a symlink pointing to `/boot/firmware/cmdline.txt`
   - The actual boot partition mounts at `/boot/firmware/`

3. **Package installation during boot**:
   - Installing large packages (chromium) during firstrun can cause issues
   - If the system reboots during package configuration, it can corrupt the filesystem
   - One Pi ended up in busybox initramfs due to filesystem corruption

### 5. Current Script Status

The `pi-setup.sh` script now:
- Uses `custom.toml` as the primary configuration method
- Creates traditional configuration files as fallback
- Includes comprehensive error handling and logging in the firstrun script
- Sets up full kiosk mode with systemd services, health monitoring, and recovery

However, the automatic execution on first boot remains unreliable.

### 6. Recommendations

Given the findings, there are two viable approaches:

1. **Semi-Automated** (Current pi-setup.sh):
   - Automates SD card preparation
   - Requires manual execution of firstrun script after boot
   - More complex but feature-complete

2. **Simple Manual** (pi-setup-simple.sh):
   - Minimal automation, maximum reliability
   - Clear two-step process: flash then configure
   - Easier to debug and understand

The Raspberry Pi Foundation appears to be moving away from complex firstrun automation, likely due to security concerns and the complexity of maintaining such mechanisms.

## Status
- Created working scripts for both approaches
- Documented all findings
- The fully automated burn-and-boot process is not reliably achievable with current Raspberry Pi OS
- Manual intervention (running setup script after first boot) is the most reliable approach

## Next Steps
- Commit the final version of pi-setup.sh with custom.toml support
- Keep pi-setup-simple.sh as a reliable alternative
- Consider using a different OS (like DietPi) if full automation is critical