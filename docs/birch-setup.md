# PANIC! Birch setup

The Birch Level 3 installation is four TCL 4K TVs, each driven by a Raspberry Pi
attached to it, plus four Vestaboards. It runs the "Decoding AI" network
(network 12) through installation 4, and each display is a watcher on that
installation:

| display | watcher | URL                             |
| ------- | ------- | ------------------------------- |
| TV 1--4 | `tv1`--`tv4` | `https://panic.fly.dev/i/4/tvN` |
| Vestaboards | `panic1`--`panic4` | driven by the server, no browser |

The eight watchers share a stride of 8 and sit at different offsets, so each one
shows a different step of the run as it cycles.

## Waking the installation up

The Pis boot straight into their kiosk URL --- there is nothing to type on the
TVs. If the screens are blank, the kiosks are stopped; bring them back with

```bash
./rpi/kiosk.sh start
```

from a machine on the tailnet. `./rpi/kiosk.sh status` shows what each Pi is
doing. The Pis stay on the tailnet whether or not the kiosks are running, and
rejoin by themselves after a power cycle.

## Starting a run

On any laptop or tablet:

- go to the [panic landing page](https://panic.fly.dev/) and log in
- open the [terminal page](https://panic.fly.dev/networks/12/terminal) and type
  a prompt to kick off a run (hit enter to start it)

The TVs and Vestaboards pick the run up on their own.

## Stopping

Go to the [network page](https://panic.fly.dev/networks/12) and hit "Stop"
towards the top. **Do this when you're done** --- otherwise PANIC! keeps running
indefinitely and burns through our AI platform credits.

If the installation is finished for a while, also stop the kiosks:

```bash
./rpi/kiosk.sh stop
```

Each running kiosk holds a websocket open to the server, which keeps the Fly
machine awake and billing even when no run is going. Stopping them lets it sleep
until someone visits the site again.

## Other notes

- there might be a delay when you start a run with a new prompt, because
  Replicate (where the models are hosted) may need to load them into memory.
  Once they're warm it moves through the text/image outputs pretty quickly.

- the Vestaboards sometimes get "behind" the TVs. You don't need to do anything;
  they'll catch back up.
