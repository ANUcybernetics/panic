# Raspberry Pi kiosk setup

The PANIC! displays are Raspberry Pi 5s that boot straight into fullscreen
Chromium (labwc, Wayland) showing a kiosk URL, and join the tailnet on first
boot.

## Flashing a card

Cards are flashed with `pi-kiosk` from Ben's dotfiles
(`~/.dotfiles/bin/pi-kiosk`, see `pi-kiosk --help`). It writes Raspberry Pi OS
with a cloud-init config, and `--tailscale-tag` mints a single-use,
pre-authorised Tailscale key through the OAuth client in the mise env. Its
default account is `kiosk`, so pass `--username panic` --- `kiosk.sh` connects
as `panic`:

```bash
pi-kiosk --url https://panic.fly.dev/i/4/tv5 --hostname panic-tv5 \
  --username panic --password … \
  --tailscale-tag tag:signage --ssh-key ~/.ssh/id_ed25519.pub
```

Once the Pi is on the tailnet, run `./rpi/kiosk.sh install` to add the dormant
drop-in (below). First boot takes a few minutes.

## Remote management

To start or stop every PANIC! kiosk at once, use `kiosk.sh` from the repo root
rather than driving systemd on each Pi by hand --- it also keeps them stopped
across a reboot and the nightly restart timer, which `systemctl stop` alone does
not:

```bash
./rpi/kiosk.sh status
./rpi/kiosk.sh stop     # blank the displays; lets the Fly machine autostop
./rpi/kiosk.sh start
./rpi/kiosk.sh install  # (re)install the units; start and stop also do this
```

Besides the dormant flag, the units include a watchdog (`kiosk-watchdog`, run
every five minutes by `chromium-watchdog.timer`) that restarts Chromium when it
is stuck on an error page or a crashed renderer. It checks the page over a local
DevTools port on 9222, so Chromium runs on its own profile in
`~/.cache/chromium-kiosk`.

For one-off work on a single Pi:

```bash
tailscale ssh panic@<hostname>

# Change kiosk URL
kiosk-set-url                          # View current URL
sudo kiosk-set-url https://new-url.com # Change URL

# View logs and status
systemctl --user status chromium-kiosk.service  # Check status
journalctl --user -u chromium-kiosk -f          # View logs
systemctl --user restart chromium-kiosk.service # Restart browser

# Check all kiosks on Tailscale
tailscale status | grep panic-tv
```

## Troubleshooting

**Pi doesn't join Tailscale network:**

- Verify the Pi has network connectivity
- The minted key is single-use and expires; reflash with a fresh one
- Check logs: `sudo journalctl -u tailscaled`

**Display issues:**

- labwc automatically detects and uses native resolution
- For 4K displays, ensure HDMI cable supports 4K@60Hz
- Check logs: `journalctl --user -u chromium-kiosk -n 50`
- Verify display: `wlr-randr` (when logged in via SSH)

**Audio not working:**

- Check audio: `pactl info` or `amixer`
- Test audio: `speaker-test -c 2`

**WiFi not connecting:**

- Verify credentials are correct
- View network status: `nmcli device status`
- Check logs: `sudo journalctl -u NetworkManager`
