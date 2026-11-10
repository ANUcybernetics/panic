# PANIC! Birch setup

The Birch Level 3 installation is four TCL 4K TVs, each driven by a Raspberry Pi
attached to it, plus four Vestaboards. Whatever network is showing there, it
runs through an installation with eight watchers:

| display     | watcher            | shows                                        |
| ----------- | ------------------ | -------------------------------------------- |
| TV 1--4     | `tv1`--`tv4`       | `https://panic.fly.dev/i/<installation>/tvN` |
| Vestaboards | `panic1`--`panic4` | driven by the server, no browser             |

The watchers share a stride of 8 and sit at different offsets (TVs on 0, 2, 4,
6; Vestaboards on 1, 3, 5, 7, with `panic1` also showing the prompt), so the TVs
show the images and the Vestaboards the text, each a different step of the run.
That layout suits a network of eight models alternating text-to-image and
image-to-text. Captioners for the boards should keep their text to 6 lines of 22
characters.

## Choosing what the TVs show

The Birch setup is one installation, "Birch Level 3", and each Pi's kiosk boots
into its watcher's URL (in the Pi's `kiosk-url.txt`; see
[`kiosk/README.md`](../kiosk/README.md)). To show another network, pick it on
the installation's edit page: the TVs switch to it straight away, and the
Vestaboards show its runs, with nothing to change on the Pis. Don't make a
second installation for the new network: every installation with Vestaboard
watchers drives the same four boards, so two of them running at once would fight
over the boards.

## Waking the installation up

The TVs need turning on at the wall. The Pis boot straight into their kiosk URL,
so there is nothing to type on the TVs. If the screens are blank, the kiosks are
stopped; bring them back with

```bash
./kiosk/kiosk.sh start
```

from a machine on the tailnet. `./kiosk/kiosk.sh status` shows what each Pi is
doing and which URL it's on. The Pis stay on the tailnet whether or not the
kiosks are running, and rejoin by themselves after a power cycle.

## Starting a run

On any laptop or tablet, log in at the
[panic landing page](https://panic.fly.dev/), open the network's terminal page
(`/networks/<id>/terminal`) and type a prompt. Admins can also start one over
the [JSON API](../README.md#json-api) with the network's `start_run` route. The
TVs and Vestaboards pick the run up on their own.

## Letting visitors prompt

Set the network's "Anonymous terminal (minutes)" (`anon_terminal_minutes` in the
API) and the installation's first TV watcher shows a small QR code in its bottom
right. Scanning it opens a terminal that can re-prompt the network, without
logging in, for that many minutes; the code changes every minute, so a photo of
it soon stops working. The network's lockout still applies. Clear the setting to
take the QR code down.

## Stopping

Hit "Stop" on the network's page (`/networks/<id>`). A run slows down as it ages
(see `Panic.Engine.Schedule`) but never stops by itself, so **stop it when
you're done** to save AI platform credits.

If the installation is finished for a while, also stop the kiosks:

```bash
./kiosk/kiosk.sh stop
```

Each running kiosk holds a websocket open to the server, which keeps the Fly
machine awake and billing even when no run is going. Stopping them lets it sleep
until someone visits the site again.

## Other notes

- a model that fails (a refusal, a hang, an outage) has a stand-in model take
  its turn, or failing that its last output reused, so a run can pause for a few
  minutes but carries on (see `Panic.Engine.Changes.InvokeModel`)
- TVs 2 and 3 won't take 3840×2160 at 60 Hz (probably an HDMI input setting on
  those TVs), and left alone their Pis pick 4096×2160 at 24 Hz, which is wider
  than 16:9. So those two Pis pin 3840×2160 at 30 Hz in
  `~/.config/kanshi/config`; TVs 1 and 4 run at 60 Hz with no config. kanshi
  only applies the profile at boot, so to change the mode on a running Pi, also
  run `wlr-randr --output HDMI-A-1 --mode <mode>` in its Wayland session
- the Vestaboards sometimes get "behind" the TVs. You don't need to do anything;
  they'll catch back up
