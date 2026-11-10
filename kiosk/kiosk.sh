#!/usr/bin/env bash
#
# Start and stop the PANIC! kiosk browsers, over Tailscale.
#
#   ./kiosk/kiosk.sh status
#   ./kiosk/kiosk.sh stop     # blank the displays, let the Fly machine sleep
#   ./kiosk/kiosk.sh start    # bring the installation back up
#
# Every tailnet host named panic-* is a PANIC! kiosk, built by `kiosk` from
# Ben's dotfiles (see kiosk/README.md). They stay on the tailnet either way:
# this only controls whether Chromium is up. That matters for the hosting bill
# as much as the displays --- each kiosk holds a LiveView websocket open, which
# counts as traffic to Fly, so while any of them is running the machine can
# never autostop.
#
# "Stopped" has to survive a reboot and the kiosk's nightly
# chromium-restart.timer, and the unit can't be masked (it lives in
# ~/.config/systemd/user, so mask collides with the unit file itself). Instead
# a drop-in gives the service a ConditionPathExists on a flag file, which makes
# starting it a no-op no matter who asks --- the labwc autostart, the timer, or
# default.target.

set -euo pipefail

readonly KIOSK_USER="kiosk"
readonly FLAG=".panic-kiosk-dormant"
readonly UNIT="chromium-kiosk.service"

hosts() {
    if [[ -n "${PANIC_KIOSK_HOSTS:-}" ]]; then
        echo "$PANIC_KIOSK_HOSTS"
    else
        tailscale status | awk '$2 ~ /^panic-/ { print $2 }'
    fi
}

on_kiosk() {
    local host="$1"
    shift
    tailscale ssh "${KIOSK_USER}@${host}" "$@"
}

ensure_dropin() {
    on_kiosk "$1" "mkdir -p ~/.config/systemd/user/${UNIT}.d &&
        printf '[Unit]\nConditionPathExists=!%%h/${FLAG}\n' \
            > ~/.config/systemd/user/${UNIT}.d/dormant.conf &&
        systemctl --user daemon-reload"
}

cmd_stop() {
    ensure_dropin "$1"
    on_kiosk "$1" "touch ~/${FLAG} && systemctl --user stop ${UNIT}"
    echo "stopped"
}

cmd_start() {
    ensure_dropin "$1"
    on_kiosk "$1" "rm -f ~/${FLAG} && systemctl --user start ${UNIT}"
    echo "started"
}

cmd_status() {
    # shellcheck disable=SC2016 # expands on the kiosk, not here
    on_kiosk "$1" '
        state=$(systemctl --user is-active chromium-kiosk.service 2>/dev/null || true)
        if [ -e ~/.panic-kiosk-dormant ]; then state="$state (dormant)"; fi
        url=$(cat /boot/firmware/kiosk-url.txt 2>/dev/null ||
            cat /etc/kiosk-url.txt 2>/dev/null || echo "?")
        printf "%-18s %s\n" "$state" "$url"
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
