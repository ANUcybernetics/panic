# Kiosks

The PANIC! displays are web kiosks that boot straight into fullscreen Chromium
showing a watcher URL and join the tailnet on first boot. They're built with
`kiosk` from Ben's dotfiles (`~/.dotfiles/bin/kiosk`), the same as every other
School kiosk; its header comment and `kiosk --help` cover the targets, wifi,
Tailscale, the watchdog and changing the URL later.

Name every PANIC! kiosk `panic-*`, which is how `kiosk.sh` finds them. The Birch
TVs are Dell Wyse 5070s on ethernet, each installed over the network from a
machine it's cabled to:

```bash
kiosk --target wyse --interface eno1 --hostname panic-tv1 \
  --url https://panic.fly.dev/i/<installation>/tv1 \
  --tailscale-tag tag:signage --ssh-key ~/.ssh/id_ed25519.pub
```

Add `--output-mode 3840x2160@30Hz` for a TV that won't take its preferred mode
(see [`docs/birch-setup.md`](../docs/birch-setup.md)).

## Starting and stopping

To start or stop every PANIC! kiosk at once, use `kiosk.sh` from the repo root
rather than driving systemd on each kiosk by hand --- it also keeps them stopped
across a reboot and the nightly restart, which `systemctl stop` alone does not:

```bash
./kiosk/kiosk.sh status
./kiosk/kiosk.sh stop     # blank the displays; lets the Fly machine autostop
./kiosk/kiosk.sh start
```

For one-off work on a single kiosk, `tailscale ssh kiosk@<hostname>`, then
`sudo kiosk-set-url <url>` to change its URL or
`journalctl --user -u chromium-kiosk` for the browser's logs.
