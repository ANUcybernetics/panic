# TODO

- get dietpi script fully working
- make sure that terminal shows the lockout timer for non-logged-in users

- long-running debug (w/sound) on the commbox
- add the "restart on error" logic (because it's better than the alternative)
- there's still something funky going on with Network deletion (and cascades)
- have a QR code that points to the model's "about" page on all installation
  displays (bottom RH corner)
- create a new `Display` domain or similar (because Installations and Watchers
  shouldn't really be in `Engine`)
- add an image->image flux model (and perhaps a way to still kick it off with
  text)
- the model select component is still a bit messy... could go back to
  LiveSelect, or even just a small phx-hook with a regular input (plus thinking
  about the validation of last->first looping)

## Thought Bubbles

- write the vis in webgl (or use the current package, but randomize between a
  few different [styles](https://audiomotion.dev/demo/))
- update to tailwind 4.0, and use the text shadow stuff (actually this might
  happen with Phoenix 1.8)
- add the ability to specify multiple offsets for single screen view
- show multiple invocations in info view
- why aren't <p>s geting margins in prose blocks in info view?
- model view (w/hand-written description)
- store invocation metadata (also add burn rate for a given network)
- make unauthenticated login not forget which page you were going to
- refactor models to just be boring has_many/belongs_to relationships, rather
  than arrays
- make regular backups of the sqlite db file (inc. a way to restore from them,
  for changing machines)
- have a "pre-warm all network models" option, which would fire off an API call
  for all models at startup
- add an indicator to the model select component to say a) if the network has
  been saved b) if it's runnable c) if it's currently running
- add a "restart from invocation" UI option
- add cost/credit balance lookup stuff to the user UI
- git cleanup: tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at
  AusCyber, v2 is Birch install)
- add video support (maybe... need to figure out how to handle video inputs as
  well)
