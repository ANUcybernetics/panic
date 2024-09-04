# Panic TODO

- for MSC, populate the whole list on focus
- make MSC store (as an assign) the list of models (on "change"), and
- terminal (which can then be used for testing)
- make invocation run in a before transaction hook (for better concurrency
  maybe?)
- `req_new` pulls API keys from the user (with tests)
- add views
  - network
    - assigns: network, ready_at (ts), invocations (stream, if running), form,
      watchers (presence?), screen/grid params (to be passed to live component)
  - "panic button" landing page
  - livegrid component
  - prediction component
    - text x image x audio grid (as per notebook)
- pubsub notifications for all new/updated invocations
- flesh out the tests to make sure the authorisation policies work properly
  (mostly adding "negative versions" of current positive tests)
- put all the identities/unique constraints in
- set up tigris to host the images (because replicate outputs now expire in 1h)
- add embeddings for all outputs (possibly via an ash oban trigger)
- add "slow down over time" (and scheduling) logic to runs
- write model descriptions
- TDA code
- add HUD or other vis for
- go back to the model IO type validation stuff and figure out a nicer way to do
  that (perhaps a validation module?)

### good citizen things

- log some issues to ash_sqlite
  - mostly around alter table
  - change "manual" pk to an int one
  - rename attribute (might work?)

### ideas (not necessarily TODO, but y'know...)

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
