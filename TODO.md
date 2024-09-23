# Panic TODO

- update the "disabled within 30s" logic so that when a new seq==0 invocation is
  completed, some sort of timer is started which disables the input, but when it
  ticks down it's re-enabled
- add views
  - "panic button" landing page
  - invocation function component
    - text x image x audio grid (as per notebook)
- add Vestaboards (to Models, perhaps?)
- add an indicator to the model select component to say a) if the network has
  been saved and b) if it's runnable
- allow "display" screens to be un-logged-in
  - put all the identities/unique constraints in
- set up tigris to host the images (because replicate outputs now expire in 1h)
- add embeddings for all outputs (another Oban worker)
- add "slow down over time" (and scheduling) logic to runs
- write model descriptions (perhaps in md and use
  [MDEx](https://github.com/leandrocp/mdex))
- TDA code
- add cost/credit balance lookup stuff to the user UI
- add HUD or other vis for
- refactor user/network liveviews to use streams for the lists

- honestly, not 100% sure there's not a race condition in the invoker (should
  enqueue next job) logic

### good citizen things

- log some issues to ash_sqlite
  - mostly around alter table
  - change "manual" pk to an int one
  - rename attribute (might work?)

### ideas (not necessarily TODO, but y'know...)

- flesh out the tests to make sure the authorisation policies work properly
  (mostly adding "negative versions" of current positive tests)
- there's some messiness around whether the platform invoke fns should know
  about the Model structs... currently they do. the issue is that maybe the
  per-model transformation stuff should all be in the :invoke key of the model,
  and the platform invoker function should just take "plain" args for path,
  version, input etc. or maybe them knowing about the model is ok.
- use [this](https://departuremono.com) for the font and
  [this](https://ryanmulligan.dev/blog/css-property-new-style/) for the fancy
  panic button (although the latter probs won't work on the silk browsers)
- add "alias" links for a given network (or maybe just use the slugs in the URL
  anyway), or even just have a `/links` page (still hosted on Panic) of links to
  e.g. "TV screens", which would really help with entering the long URLs on TV
  screens
- audio vis with [this](https://audiomotion.dev/demo/multi.html)?
- git cleanup: tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at
  AusCyber, v2 is Birch install)
- add QR code function component (with rolling cookie/URL param)
- add oblique strategies model (GPT-4 powered)
- upgrade to liveview 1.0-rc (probably best to wait for ash_phoenix to do it)
- clear the terminal input when a new prediction is triggered (well, actually
  it's
  [this issue](https://github.com/phoenixframework/phoenix_live_view/issues/624),
  so maybe not worth getting bogged down on)
- add prsence to network views so that it'll say how many people are watching a
  particular network
