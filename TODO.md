# Panic TODO

- sort out display of audio things (waveform for TVs, but audio for playback?)
- add a non-logged in network view (to share with attendees)
- delete old files from tigris
- QR code for above, plus an index of all QR links for a user's network
- add access control the the user/network pages
- test multiple simultaneous networks (from different users)
- add terminal input to :grid view (if logged in)
- refocus the model select component on selection
- write network & model descriptions
- come up with some cool networks (at least one per day), write descriptions
- unplug the network and see how gracefully it fails
- make screen recording for backup purposes
- add/modify an "admin" panel which I can access on mobile (with e.g. stop all,
  maybe even logs?)

## mac mini

- paint Enter key on keyboard?
- set up desktop bg (launch panic script, WT folder)
- test with speaker
- make sure we've got QR cable and extra ethernet for mac mini
- get iPad (for demo, QR code purposes)

## for v2 proper, but not (necessarily) for SXSW

- model view
- store invocation metadata
- make unauthenticated login not forget which page you were going to
- add embeddings for all outputs (another Oban worker)
- add HUD or other vis for the embedding trajectories
- TDA code

## ideas (not necessarily TODO, but y'know...)

- download sqlite file as backup
- screen/display layout should be h/w full?
- instead of hosting the nsfw placeholder and audio waveform pictures on tigris,
  serve them from priv/static/images (the files are already in there)
- a "waiting" timer on all pending invocations (better still, with feedback for
  e.g. replicate on what the actual status was)
- replace the "split into `<p>`s based on double newline with proper md parsing
- instead of `use DisplayStreamer`, perhaps can just have an on_mount hook?
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
- add a "restart from invocation" UI option
- add cost/credit balance lookup stuff to the user UI
- get regular backups of the sqlite db file
- use [this](https://ryanmulligan.dev/blog/css-property-new-style/) for the
  fancy panic button (although the latter probs won't work on the silk browsers)
- add "alias" links for a given network (or maybe just use the slugs in the URL
  anyway)
- git cleanup: tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at
  AusCyber, v2 is Birch install)
- add oblique strategies model (GPT-4 powered)
- upgrade to liveview 1.0 (but only when ash_phoenix does it?, so maybe not
  worth getting bogged down on)
- add presence to network views so that it'll say how many people are watching a
  particular network
- see if there's a nicer way to handle the vestaboards - the current way is
  better than before, but still a bit "edge-case-y" and hacky for my liking
- add more platforms:
  - claude
  - gemini/vertex AI
  - https://www.inference.net

## fly.io deployment notes

- first, destroyed the old panic (app & machines)
- did a clean(ish) fly deploy, to auto-detect Phoenix and provide the latest
  suggested config
- then got stuck in a boot loop, will investigate tomorrow
