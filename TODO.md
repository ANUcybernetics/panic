# Panic TODO

- add animated "panic button" function component (for landing, waiting,
  bottom-right branding etc.)
- check that the feedback is good with the lockout button
- upon tigris upload, change input of child invocation as well as output of
  parent (perhaps rename to archiver)
- put all the identities/unique constraints in
- test the new switch
- add the old captioners back, and maybe blip1 - need to get a better story
  there I think
- test multiple simultaneous networks (e.g. for Thomas)
- add embeddings for all outputs (another Oban worker)
- write model descriptions (perhaps in md and use
  [MDEx](https://github.com/leandrocp/mdex))
- add a non-logged in network view (to share with attendees)
- test Panic button, find keyboard, set up Mac Mini (inc. WT desktop folder),
  grab PA speaker from c/c/c lab
- add/modify an "admin" panel which I can access on mobile (with e.g. stop all,
  maybe even logs?)
- check what happens in prod if someone goes to an empty/non-existent network

## for v2 proper, but not (necessarily) for SXSW

- add HUD or other vis for the embedding trajectories
- TDA code
- add [QR code function component](https://github.com/zhengkyl/qrframe) (with
  rolling cookie/URL param)

## ideas (not necessarily TODO, but y'know...)

- a "waiting" timer on all pending invocations (better still, with feedback for
  e.g. replicate on what the actual status was)
- replace the "split into `<p>`s based on double newline with proper md parsing
- store the metadata
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
- use [this](https://departuremono.com) for the font and
  [this](https://ryanmulligan.dev/blog/css-property-new-style/) for the fancy
  panic button (although the latter probs won't work on the silk browsers)
- add "alias" links for a given network (or maybe just use the slugs in the URL
  anyway)
- git cleanup: tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at
  AusCyber, v2 is Birch install)
- add oblique strategies model (GPT-4 powered)
- upgrade to liveview 1.0-rc (probably best to wait for ash_phoenix to do it) so
  maybe not worth getting bogged down on)
- add presence to network views so that it'll say how many people are watching a
  particular network
- see if there's a nicer way to handle the vestaboards - the current way is
  better than before, but still a bit "edge-case-y" and hacky for my liking
- add more platforms:
  - claude
  - gemini/vertex AI
  - https://www.inference.net

## deployment notes

- first, destroyed the old panic (app & machines)
- did a clean(ish) fly deploy, to auto-detect Phoenix and provide the latest
  suggested config
- then got stuck in a boot loop, will investigate tomorrow
