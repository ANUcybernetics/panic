# Panic TODO

- update docstrings in invoker module
- allow "display" screens to be un-logged-in
  - put all the identities/unique constraints in
- set up tigris to host the images (because replicate outputs now expire in 1h)
- test Vestaboards
- add audio (perhaps with [this](https://audiomotion.dev/demo/multi.html)?)
- test the new switch
- update models
- put it on fly.io
- add helper for listing all the "screen" links
- add embeddings for all outputs (another Oban worker)
- add "slow down over time" (and scheduling) logic to runs
- write model descriptions (perhaps in md and use
  [MDEx](https://github.com/leandrocp/mdex))
- test Panic button, find keyboard, set up Mac Mini
- add/modify an "admin" panel which I can access on mobile (with e.g. stop all)

## for v2 proper, but not (necessarily) for SXSW

- add animated "panic button" function component (maybe?)
- add HUD or other vis for the embedding trajectories
- TDA code
- add [QR code function component](https://github.com/zhengkyl/qrframe) (with
  rolling cookie/URL param)

## ideas (not necessarily TODO, but y'know...)

- replace the "split into `<p>`s based on double newline with proper md parsing
- add <https://www.inference.net> platform
- store the metadata
- refactor user/network liveviews to use streams for the lists
- add an indicator to the model select component to say a) if the network has
  been saved b) if it's runnable c) if it's currently running
- flesh out the tests to make sure the authorisation policies work properly
  (mostly adding "negative versions" of current positive tests)
- there's some messiness around whether the platform invoke fns should know
  about the Model structs... currently they do. the issue is that maybe the
  per-model transformation stuff should all be in the :invoke key of the model,
  and the platform invoker function should just take "plain" args for path,
  version, input etc. or maybe them knowing about the model is ok.
- add cost/credit balance lookup stuff to the user UI
- use [this](https://departuremono.com) for the font and
  [this](https://ryanmulligan.dev/blog/css-property-new-style/) for the fancy
  panic button (although the latter probs won't work on the silk browsers)
- add "alias" links for a given network (or maybe just use the slugs in the URL
  anyway), or even just have a `/links` page (still hosted on Panic) of links to
  e.g. "TV screens", which would really help with entering the long URLs on TV
  screens
- git cleanup: tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at
  AusCyber, v2 is Birch install)
- add oblique strategies model (GPT-4 powered)
- upgrade to liveview 1.0-rc (probably best to wait for ash_phoenix to do it) so
  maybe not worth getting bogged down on)
- add presence to network views so that it'll say how many people are watching a
  particular network
