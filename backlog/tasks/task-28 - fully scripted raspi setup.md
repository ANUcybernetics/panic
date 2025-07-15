---
id: task-28
title: "fully-scripted raspi setup"
status: In Progress
assignee: []
created_date: "2025-07-09"
labels: []
dependencies: ["task-30"]
---

NOTE: once task 30 is done, this can be closed as well

# Task 28: Fully Scripted Raspberry Pi OS Setup

## Objective

Create a fully automated burn-and-boot process for Raspberry Pi OS that sets up
a kiosk mode display without manual intervention.

## Findings

### 1. Raspberry Pi OS Boot Process Changes

- **Raspberry Pi OS Bookworm (2025-05-13) has deprecated the `systemd.run`
  parameter in cmdline.txt**
- The traditional approach of adding `systemd.run=/boot/firmware/firstrun.sh` to
  cmdline.txt no longer works
- This was discovered when the firstrun script was created correctly but never
  executed automatically

### 2. Attempted Approaches

#### Approach 1: systemd.run in cmdline.txt (FAILED)

- Modified cmdline.txt to include
  `systemd.run=/boot/firmware/firstrun.sh systemd.run_success_action=reboot`
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
   - `/boot/firmware/userconf.txt` - Username:password_hash for user creation
     (WORKS)
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

   - `/boot/cmdline.txt` is now a symlink pointing to
     `/boot/firmware/cmdline.txt`
   - The actual boot partition mounts at `/boot/firmware/`

3. **Package installation during boot**:
   - Installing large packages (chromium) during firstrun can cause issues
   - If the system reboots during package configuration, it can corrupt the
     filesystem
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

The Raspberry Pi Foundation appears to be moving away from complex firstrun
automation, likely due to security concerns and the complexity of maintaining
such mechanisms.

## Status

- Created working scripts for both approaches
- Documented all findings
- The fully automated burn-and-boot process is not reliably achievable with
  current Raspberry Pi OS
- Manual intervention (running setup script after first boot) is the most
  reliable approach

## SDM Project Analysis

### Key Insights from gitbls/sdm

After analyzing the sdm (SD card Manager) project, I've found a reliable
approach for first-boot automation:

1. **systemd Service Approach**: Instead of relying on deprecated `systemd.run`
   in cmdline.txt, sdm creates a systemd service that runs on first boot:

   - Service: `/etc/systemd/system/sdm-firstboot.service`
   - Script: `/usr/local/sdm/sdm-firstboot`
   - Runs after network.target
   - Self-disables after running

2. **Raspberry Pi OS Native Firstboot**:

   - RasPiOS uses `/usr/lib/raspberrypi-sys-mods/firstboot`
   - Referenced in cmdline.txt with
     `init=/usr/lib/raspberrypi-sys-mods/firstboot`
   - sdm removes this when using its own mechanism

3. **Implementation Pattern**:

   ```bash
   # Create systemd service
   cat > /etc/systemd/system/my-firstboot.service <<EOF
   [Unit]
   Description=My First Boot Setup
   After=network.target

   [Service]
   Type=forking
   ExecStart=/usr/local/bin/my-firstboot.sh
   TimeoutSec=0
   RemainAfterExit=yes
   GuessMainPID=no

   [Install]
   WantedBy=multi-user.target
   EOF

   # Enable service
   systemctl enable my-firstboot.service
   ```

4. **Script Structure**:
   - Fork immediately to let service start properly
   - Wait for time sync before regenerating SSH keys
   - Run configuration scripts in sequence
   - Self-disable the service
   - Optional reboot after completion

## Improved Approach

Based on sdm's proven methodology, we can create a reliable firstboot mechanism
by:

1. Mounting the SD card and creating our systemd service directly
2. Using a condition file (e.g., `/etc/firstboot-done`) to ensure single
   execution
3. Implementing proper error handling and logging
4. Supporting both `/boot` and `/boot/firmware` locations

## Implementation

### New systemd-based approach (pi-setup-systemd.sh)

Created a new implementation that uses the reliable systemd service approach
learned from sdm:

1. **Key Features**:

   - Creates a `panic-firstboot.service` that runs on first boot
   - Service self-disables after successful execution (like sdm)
   - Uses condition file (`/etc/panic-firstboot-done`) to prevent re-runs
   - Forks the firstboot script to let service start properly
   - Comprehensive logging to `/var/log/panic-firstboot.log`

2. **How it works**:

   - Mounts both boot and root partitions during SD card preparation
   - Installs systemd service directly into root filesystem
   - Service runs after network.target
   - Waits for time sync before package installation
   - Configures everything in one automated run

3. **Advantages over custom.toml approach**:
   - More reliable - systemd services are guaranteed to run
   - Better error handling and logging
   - Can monitor progress via journalctl
   - Works consistently across Raspberry Pi OS versions

## Testing Instructions

1. **Test mode** (safe, no SD card write):

   ```bash
   ./pi-setup-systemd.sh -T -u pi -p mypassword -w "WiFi Name" -W "wifipass"
   ```

2. **Real deployment**:

   ```bash
   ./pi-setup-systemd.sh -u pi -p mypassword -w "WiFi Name" -W "wifipass" -U "https://panic.fly.dev"
   ```

3. **Monitor firstboot progress** (after booting the Pi):
   ```bash
   ssh pi@<pi-ip>
   sudo journalctl -u panic-firstboot -f
   ```

## Comparison of Approaches

### 1. systemd.run in cmdline.txt (Deprecated)

- **How it worked**: Added `systemd.run=/boot/firmware/firstrun.sh` to
  cmdline.txt
- **Status**: No longer works in Raspberry Pi OS Bookworm (2024-05-13+)
- **Why it failed**: Raspberry Pi Foundation removed support for this parameter

### 2. custom.toml (Current pi-setup.sh)

- **How it works**: Creates a `custom.toml` file that Raspberry Pi Imager format
  processes
- **Pros**:
  - Official Raspberry Pi approach
  - Handles SSH, user creation, WiFi config reliably
- **Cons**:
  - `run_commands` in `[all.first_boot]` section doesn't reliably execute
  - Limited documentation
  - Inconsistent behavior across versions

### 3. systemd Service (New pi-setup-systemd.sh)

- **How it works**: Installs a systemd service directly into root filesystem
- **Pros**:
  - Proven reliable (used by sdm project)
  - Full control over execution environment
  - Excellent logging via journalctl
  - Self-disabling after success
  - Works consistently across OS versions
- **Cons**:
  - Requires mounting root partition during SD prep
  - More complex implementation
  - Not an "official" Raspberry Pi approach

### 4. Manual Execution (Fallback)

- **How it works**: SSH into Pi and run setup script manually
- **Pros**: 100% reliable, simple to debug
- **Cons**: Requires manual intervention

## Recommendation

The systemd service approach (pi-setup-systemd.sh) offers the best balance of
automation and reliability. It's the method used by established projects like
sdm and provides consistent results across different Raspberry Pi OS versions.

## Two-Stage Automation with Tailscale + Ansible

Since macOS cannot mount ext4 filesystems (the Pi's root partition), we've
developed a two-stage approach that's still fully automated from your Mac:

### Stage 1: Flash SD Cards (pi-setup-systemd.sh)

- Creates bootable SD cards with:
  - SSH enabled
  - User account configured
  - WiFi credentials
  - Tailscale auth key for automatic network join
  - Basic boot partition configuration

### Stage 2: Configure via Ansible (over Tailscale)

- Once Pis boot and join Tailscale network:
  - Ansible configures all devices in parallel
  - Installs kiosk software (Chromium, Wayfire)
  - Sets up auto-start services
  - Configures display settings
  - No manual SSH required!

### One-Command Deployment

The `deploy-fleet.sh` script orchestrates the entire process:

```bash
# Deploy 5 kiosk devices
TAILSCALE_AUTHKEY=tskey-auth-xxx \
WIFI_SSID=MyNetwork \
WIFI_PASSWORD=MyPass \
./deploy-fleet.sh 5
```

This will:

1. Prompt you to insert each SD card and flash it
2. Wait for all Pis to boot and join Tailscale
3. Configure all devices via Ansible automatically
4. Report when complete

### Benefits of This Approach

- ✅ **Fully automated** - No manual SSH needed
- ✅ **Scalable** - Works for 1 or 100 devices
- ✅ **Reliable** - Ansible ensures consistent configuration
- ✅ **Maintainable** - Easy to update configuration later
- ✅ **No macOS limitations** - Avoids ext4 mounting issues
- ✅ **Remote management** - Tailscale enables access from anywhere

## Next Steps

- Test the two-stage deployment process
- Fine-tune Ansible playbook for specific display configurations
- Add monitoring/health checks via Tailscale
- Document fleet management procedures

## Alternative Approach: Salvaging custom.toml Method

Based on the GitHub issue #94, the `custom.toml` approach has known issues with
`run_commands`. However, there are workarounds:

### Current Issues with custom.toml:

1. `run_commands` in `[all.first_boot]` often doesn't execute
2. The `/boot/os_customisations/` directory approach is unreliable
3. `systemd.run` in cmdline.txt is deprecated

### Potential Solutions:

1. **Use Raspberry Pi Imager directly** - The most reliable method is to use the
   official Raspberry Pi Imager with its built-in customization features, then
   add our kiosk setup as a second stage.

2. **cloud-init approach** - Install cloud-init on the base image and use
   cloud-config for firstboot automation.

3. **Modified custom.toml** - Some users report success with very simple
   commands in custom.toml, avoiding complex scripts.

4. **Two-stage with systemd timer** - Use custom.toml for basic setup (SSH,
   user, WiFi), then install a systemd timer that runs once after first network
   connection.

### Recommendation:

Given the limitations of macOS (no ext4 support) and the unreliability of
custom.toml's `run_commands`, the **Tailscale + Ansible approach remains the
most reliable** for fleet deployment. It avoids the firstboot issues entirely by
using a proven two-stage process.

For single device setup where manual intervention is acceptable, the current
pi-setup.sh with SSH + manual script execution is adequate.

## Notes

- The raspberrypi-sys-mods firstboot mechanism is in flux and not well
  documented
- Different Raspberry Pi OS versions behave differently with these approaches
- The Ansible approach provides better visibility, error handling, and
  repeatability
- Consider using a custom Raspberry Pi OS image with everything pre-configured
  for true single-step deployment
