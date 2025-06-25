# Panic TODO

- NOTE: the `f05cf94dfb08200b1e473d7f6a3419b75d35980a` isn't live yet, and the
  hidpi thing is fixed... so if it breaks again, revert that commit
- add the "restart on error" logic (because it's better than the alternative)
- check that the interaction of the "delay backoff" and "wait for vestaboards"
  logic is correct... I think that having a :not_before timestamp for the next
  invocation might be the best way?

## quality-of-life

- have a QR code that points to the model's "about" page on all installation
  displays (bottom RH corner)
- named watchers, and use those as map keys rather than array position index
  (and make them editable... perhaps with pubsub updates)
- check that time-based QR code -> terminal workflow works for non-logged-in
  users (perhaps only required for installations, and also requires real
  deployment to test properly)
- maybe rename PanicWeb.InvocationWatcher (now that there's a Watcher module) to
  WatcherLive or something similar
- make sure vestaboards crashing doesn't bring down the whole thing
- create a new `Display` domain or similar (because Installations and Watchers
  shouldn't really be in `Engine`)
- add presence to network views so that it'll say how many people are watching a
  particular network, presence for each installation watcher as well (which
  would help with knowing if installed rpis go offline)

## thought bubbles

- write the vis in webgl (or use the current package, but randomize between a
  few different [styles](https://audiomotion.dev/demo/))
- don't have api tokens per-user, have them as a standalone resource which can
  have many users (and also could be set as "default" for requests using the
  rolling QR code terminal)
- update to tailwind 4.0, and use the text shadow stuff (actually this might
  happen with Phoenix 1.8)
- honestly, it's looking less likely that this will be a "multi-user SaaS thing"
  and more like I'll always be tweaking it and making bespoke changes for our
  specific purposes... so perhaps remove the auth/policy stuff in general
- add the ability to specify multiple offsets for single screen view
- show multiple invocations in info view
- why aren't <p>s geting margins in prose blocks in info view?
- refocus and clear the model select component on selection (to allow for
  rapid-fire adding of models) or perhaps even replace with
  [this if it's better](https://hexdocs.pm/autocomplete_input/readme.html)
- model view (w/hand-written description)
- store invocation metadata (also add burn rate for a given network)
- make unauthenticated login not forget which page you were going to
- refactor models to just be boring has_many/belongs_to relationships, rather
  than arrays
- make regular backups of the sqlite db file (inc. a way to restore from them,
  for changing machines)
- have a "pre-warm all network models" option, which would fire off an API call
  for all models at startup
- for nsfw, dynamically generate the replacement image
- add an indicator to the model select component to say a) if the network has
  been saved b) if it's runnable c) if it's currently running
- add a "restart from invocation" UI option
- add cost/credit balance lookup stuff to the user UI
- git cleanup: tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at
  AusCyber, v2 is Birch install)
- add video support (maybe... need to figure out how to handle video inputs as
  well)

## NIME install notes

- soad foyer LH is #0, RH is #1
- #2 is in kambri foyer (double-check this)
