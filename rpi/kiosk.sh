#!/usr/bin/env bash
#
# Start and stop the PANIC! kiosk browsers on the Raspberry Pis, over Tailscale.
#
#   ./rpi/kiosk.sh status
#   ./rpi/kiosk.sh stop     # blank the displays, let the Fly machine sleep
#   ./rpi/kiosk.sh start    # bring the installation back up
#   ./rpi/kiosk.sh install  # (re)install the units below; start/stop also do
#
# The Pis stay on the tailnet either way: tailscaled is a system service, so
# they rejoin by themselves after a power cycle. This only controls whether
# Chromium is up. That matters for the hosting bill as much as the displays --
# each kiosk holds a LiveView websocket open, which counts as traffic to Fly,
# so while any of them is running the machine can never autostop.
#
# "Stopped" has to survive a reboot and the nightly chromium-restart.timer,
# and the unit can't be masked (it lives in ~/.config/systemd/user, so mask
# collides with the unit file itself). Instead a drop-in gives the service a
# ConditionPathExists on a flag file, which makes starting it a no-op no
# matter who asks -- the labwc autostart, the timer, or default.target.

set -euo pipefail

readonly KIOSK_USER="panic"
readonly FLAG=".panic-kiosk-dormant"
readonly UNIT="chromium-kiosk.service"

hosts() {
    if [[ -n "${PANIC_TV_HOSTS:-}" ]]; then
        echo "$PANIC_TV_HOSTS"
    else
        tailscale status | awk '$2 ~ /^panic-tv/ { print $2 }'
    fi
}

on_pi() {
    local host="$1"
    shift
    tailscale ssh "${KIOSK_USER}@${host}" "$@"
}

# The script ensure_units runs on a Pi. Three pieces, installed on demand so a
# freshly imaged Pi picks them up without a re-run of pi-setup.sh:
#   - dormant.conf, which is what makes "stopped" stick;
#   - devtools.conf, which relaunches Chromium with a DevTools port on its own
#     profile (Chromium ignores the port on the default profile);
#   - kiosk-watchdog on a five-minute timer, which restarts Chromium when it is
#     stuck on an error page or a crashed renderer. It does nothing while the
#     kiosk is stopped, so it needs no part in start/stop.
units_script() {
    cat <<EOF
set -e
d=~/.config/systemd/user
mkdir -p \$d/${UNIT}.d \$d/timers.target.wants
cat > \$d/${UNIT}.d/dormant.conf <<'X'
[Unit]
ConditionPathExists=!%h/${FLAG}
X
EOF
    cat <<'EOF'
cat > $d/chromium-kiosk.service.d/devtools.conf <<'X'
[Service]
ExecStart=
ExecStart=/bin/bash -c 'BOOT=$([ -d /boot/firmware ] && echo /boot/firmware || echo /boot); URL=$(cat "$BOOT/kiosk-url.txt" 2>/dev/null || echo "https://panic.fly.dev/"); BROWSER=$(command -v chromium || command -v chromium-browser); exec "$BROWSER" --kiosk --password-store=basic --user-data-dir=%h/.cache/chromium-kiosk --remote-debugging-port=9222 --no-first-run --noerrdialogs --disable-infobars --disable-translate --disable-pinch --disable-component-update --autoplay-policy=no-user-gesture-required --check-for-update-interval=31536000 --ozone-platform=wayland "$URL"'
X
cat > $d/chromium-watchdog.service <<'X'
[Unit]
Description=Restart Chromium kiosk if it is stuck on an error page

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kiosk-watchdog
X
cat > $d/chromium-watchdog.timer <<'X'
[Unit]
Description=Check the Chromium kiosk every 5 minutes

[Timer]
OnBootSec=10min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
X
ln -sf ../chromium-watchdog.timer $d/timers.target.wants/chromium-watchdog.timer
sudo tee /usr/local/bin/kiosk-watchdog >/dev/null <<'X'
EOF
    cat "$(dirname "$0")/kiosk-watchdog"
    cat <<'EOF'
X
sudo chmod 755 /usr/local/bin/kiosk-watchdog
systemctl --user daemon-reload
systemctl --user start chromium-watchdog.timer
EOF
}

ensure_units() {
    units_script | on_pi "$1" bash -s
}

cmd_stop() {
    local host="$1"
    ensure_units "$host"
    on_pi "$host" "touch ~/${FLAG} && systemctl --user stop ${UNIT}"
    echo "stopped"
}

cmd_start() {
    local host="$1"
    ensure_units "$host"
    on_pi "$host" "rm -f ~/${FLAG} && systemctl --user start ${UNIT}"
    echo "started"
}

cmd_install() {
    ensure_units "$1"
    echo "installed"
}

cmd_status() {
    on_pi "$1" '
        state=$(systemctl --user is-active chromium-kiosk.service 2>/dev/null || true)
        if [ -e ~/.panic-kiosk-dormant ]; then state="$state (dormant)"; fi
        boot=$([ -d /boot/firmware ] && echo /boot/firmware || echo /boot)
        printf "%-18s %s\n" "$state" "$(cat "$boot/kiosk-url.txt" 2>/dev/null || echo "?")"
    '
}

main() {
    local verb="${1:-status}"
    case "$verb" in
        start | stop | status | install) ;;
        *)
            echo "usage: $(basename "$0") [start|stop|status|install]" >&2
            exit 64
            ;;
    esac

    local failed=0
    for host in $(hosts); do
        printf '%-12s ' "$host"
        if ! "cmd_${verb}" "$host"; then
            echo "FAILED"
            failed=1
        fi
    done
    exit "$failed"
}

main "$@"
