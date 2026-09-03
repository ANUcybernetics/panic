#!/usr/bin/env bash
#
# Start and stop the PANIC! kiosk browsers on the Raspberry Pis, over Tailscale.
#
#   ./rpi/kiosk.sh status
#   ./rpi/kiosk.sh stop     # blank the displays, let the Fly machine sleep
#   ./rpi/kiosk.sh start    # bring the installation back up
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

# The drop-in is what makes "stopped" stick; install it on demand so a freshly
# imaged Pi picks it up without a re-run of pi-setup.sh.
ensure_dropin() {
    on_pi "$1" "
        mkdir -p ~/.config/systemd/user/${UNIT}.d
        cat > ~/.config/systemd/user/${UNIT}.d/dormant.conf <<'EOF'
[Unit]
ConditionPathExists=!%h/${FLAG}
EOF
        systemctl --user daemon-reload
    "
}

cmd_stop() {
    local host="$1"
    ensure_dropin "$host"
    on_pi "$host" "touch ~/${FLAG} && systemctl --user stop ${UNIT}"
    echo "stopped"
}

cmd_start() {
    local host="$1"
    ensure_dropin "$host"
    on_pi "$host" "rm -f ~/${FLAG} && systemctl --user start ${UNIT}"
    echo "started"
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
        start | stop | status) ;;
        *)
            echo "usage: $(basename "$0") [start|stop|status]" >&2
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
