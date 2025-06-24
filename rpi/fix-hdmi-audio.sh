#!/bin/bash
# AIDEV-NOTE: Standalone script to fix HDMI audio on Raspberry Pi 5 with Debian Bookworm
# Usage: curl -sSL https://raw.githubusercontent.com/ANUcybernetics/panic/main/rpi/fix-hdmi-audio.sh | bash
# Or: wget -qO- https://raw.githubusercontent.com/ANUcybernetics/panic/main/rpi/fix-hdmi-audio.sh | bash

set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

readonly CURRENT_USER=$(whoami)
readonly WIREPLUMBER_DROPDIR="/home/$CURRENT_USER/.config/systemd/user/wireplumber.service.d"

echo "🔊 Fixing HDMI audio on Raspberry Pi..."
echo "👤 Current user: $CURRENT_USER"

# Check if we're on a Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo "⚠️  Warning: This doesn't appear to be a Raspberry Pi"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if PipeWire is installed
if ! command -v pipewire >/dev/null 2>&1; then
    echo "❌ PipeWire not found. Installing..."
    sudo apt update
    sudo apt install -y pipewire pipewire-pulse wireplumber
fi

echo "🔄 Restarting PipeWire audio services..."
systemctl --user restart pipewire pipewire-pulse wireplumber || {
    echo "⚠️  Failed to restart user services, trying system-wide..."
    sudo systemctl restart pipewire pipewire-pulse wireplumber || true
}

# Wait for services to stabilize
echo "⏳ Waiting for audio services to initialize..."
sleep 5

# Check for HDMI audio devices
echo "🔍 Detecting HDMI audio devices..."
if ! aplay -l | grep -q "hdmi"; then
    echo "❌ No HDMI audio devices found. Checking kernel modules..."
    if ! lsmod | grep -q "snd_soc_hdmi_codec"; then
        echo "❌ HDMI audio kernel modules not loaded"
        echo "💡 Try adding 'dtparam=audio=on' to /boot/firmware/config.txt and reboot"
        exit 1
    fi
fi

# Get the HDMI sink name (try common patterns)
HDMI_SINK=""
for pattern in "alsa_output.platform-107c701400.hdmi.hdmi-stereo" "alsa_output.*hdmi.*stereo"; do
    if pactl list short sinks | grep -q "$pattern"; then
        HDMI_SINK=$(pactl list short sinks | grep "$pattern" | head -1 | cut -f2)
        break
    fi
done

if [ -z "$HDMI_SINK" ]; then
    echo "❌ No HDMI audio sink found. Available sinks:"
    pactl list short sinks
    echo ""
    echo "💡 If you see only 'auto_null', try:"
    echo "   1. Check HDMI cable is connected"
    echo "   2. Reboot the system"
    echo "   3. Check /boot/firmware/config.txt has 'dtparam=audio=on'"
    exit 1
fi

echo "✅ Found HDMI audio sink: $HDMI_SINK"

# Set HDMI as default
echo "🎵 Setting HDMI as default audio output..."
pactl set-default-sink "$HDMI_SINK"

# Verify it worked
CURRENT_SINK=$(pactl info | grep "Default Sink:" | cut -d' ' -f3)
if [ "$CURRENT_SINK" = "$HDMI_SINK" ]; then
    echo "✅ HDMI audio is now the default output"
else
    echo "⚠️  Warning: Default sink is $CURRENT_SINK, expected $HDMI_SINK"
fi

# Create WirePlumber drop-in directory
echo "📁 Creating WirePlumber drop-in directory..."
mkdir -p "$WIREPLUMBER_DROPDIR"

# Create WirePlumber drop-in configuration for HDMI audio
echo "⚙️  Creating WirePlumber HDMI audio configuration..."
cat > "$WIREPLUMBER_DROPDIR/hdmi-audio.conf" << 'EOF'
[Service]
# When WirePlumber starts successfully, also configure HDMI audio
ExecStartPost=/bin/bash -c '\
  sleep 2; \
  HDMI_SINK=$(pactl list short sinks | grep "hdmi.*stereo" | head -1 | cut -f2); \
  if [ -n "$HDMI_SINK" ]; then \
    pactl set-default-sink "$HDMI_SINK"; \
    echo "HDMI audio auto-configured: $HDMI_SINK"; \
  fi'
EOF

# Reload systemd and restart WirePlumber to apply the drop-in
echo "🔧 Reloading systemd and applying HDMI audio configuration..."
systemctl --user daemon-reload
systemctl --user restart wireplumber.service

# Test audio
echo "🎵 Testing HDMI audio output..."
echo "   Playing 1-second test tone (1000Hz)..."
timeout 1s speaker-test -c2 -t sine -f 1000 -l 1 2>/dev/null || {
    echo "⚠️  Audio test command failed, but this might be normal"
}

# Show final status
echo ""
echo "🎉 HDMI audio configuration complete!"
echo ""
echo "📊 Current audio status:"
echo "   Default sink: $(pactl info | grep "Default Sink:" | cut -d' ' -f3-)"
echo "   WirePlumber drop-in: $([ -f "$WIREPLUMBER_DROPDIR/hdmi-audio.conf" ] && echo "configured" || echo "missing")"
echo ""
echo "🔍 Available audio sinks:"
pactl list short sinks
echo ""
echo "✅ HDMI audio should work after reboot"
echo "💡 To test audio manually: speaker-test -c2 -t wav -l 1"
echo "🔧 To check WirePlumber status: systemctl --user status wireplumber.service"
echo "📝 To view WirePlumber logs: journalctl --user -u wireplumber.service"
