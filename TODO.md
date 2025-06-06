# Panic TODO

- add tidewave and ash_ai
- add "stop all" button to admin view
- add latest text description model (via Google AI studio)
- add new replicate models (maybe archive old ones?)
- check that terminal works on mobile (and revert SXSW-specific changes)
- add video support (maybe... need to figure out how to handle video inputs as
  well)
- move the rpi chromium launch script into this repo
- double check that all the updates (esp. ash_auth_phoenix) went through ok

- replace Oban/Engine with a GenServer (or at least root out the "multiple
  simultaneous jobs" bug)

- update to tailwind 4.0, and use the text shadow stuff
- add "installation" view (which might allow us to re-jig the way vestaboards
  are handled)
- make sure vestaboards crashing doesn't bring down the whole thing
- add the ability to specify multiple offsets for single screen view
- add SAO passthrough model?
- show multiple invocations in info view
- why aren't <p>s geting margins in prose blocks in info view?
- refocus and clear the model select component on selection (to allow for
  rapid-fire adding of models)
- model view (w/hand-written description)
- add "back off over time" based on time
- store invocation metadata (also add burn rate for a given network)
- make unauthenticated login not forget which page you were going to
- add an option to redirect all watching TVs to a new view (perhaps an
  `Installation` resource, which had a "waiting room" URL where you could go and
  then the control panel would redirect all TVs to their respective views, or at
  least would direct to a network-specific "screen" list)
- now that models is an array, have them Enum.each through, but put an await so
  they're all done (this will make the Vestaboard-wait period better; it won't
  wait if the time has already elapsed)

## ideas (not necessarily TODO, but y'know...)

(many of these are out-of-date)

- refactor models (and tokens) to just be boring has_many/belongs_to
  relationships, rather than arrays
- make regular backups of the sqlite db file (inc. a way to restore from them,
  for changing machines)
- have a "pre-warm the models", based on average startup time (from metadata)
- go back into the Invoker and sort out the insert vs insert_and_queue_next
  (basically if the entry point to the invoker module could return ok, lockout
  or error that'd make the :start_run action simpler as well)
- instead of hosting the nsfw placeholder and audio waveform pictures on tigris,
  serve them from priv/static/images (the files are already in there)
- a "waiting" timer on all pending invocations (better still, with feedback for
  e.g. replicate on what the actual status was)
- each model could have a "pre/post wait" time, to account for things like
  vestaboards
- replace the "split into `<p>`s based on double newline with proper md parsing
- put `DisplayStreamer` stuff into an on_mount hook?
- refactor user/network liveviews to use streams for the lists
- add an indicator to the model select component to say a) if the network has
  been saved b) if it's runnable c) if it's currently running
- flesh out the tests to make sure the authorisation policies work properly
  (mostly adding "negative versions" of current positive tests)
- get the pool drain Oban tests working
- there's some messiness around whether the platform invoke fns should know
  about the Model structs... currently they do. the issue is that maybe the
  per-model transformation stuff should all be in the :invoke key of the model,
  and the platform invoker function should just take "plain" args for path,
  version, input etc. or maybe them knowing about the model is ok.
- add a "restart from invocation" UI option
- add cost/credit balance lookup stuff to the user UI
- add "alias" links for a given network (or maybe just use the slugs in the URL
  anyway)
- git cleanup: tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at
  AusCyber, v2 is Birch install)
- add oblique strategies model (GPT-4 powered)
- upgrade to liveview 1.0 (but only when ash_phoenix does it?, so maybe not
  worth getting bogged down on)
- add presence to network views so that it'll say how many people are watching a
  particular network
- add more platforms:
  - claude
  - https://www.inference.net

## fly.io deployment notes

- first, destroyed the old panic (app & machines)
- did a clean(ish) fly deploy, to auto-detect Phoenix and provide the latest
  suggested config
- then got stuck in a boot loop, will investigate tomorrow

## Replicate model notes

### img2txt

- blips good, usually warm (3 takes slightly longer than 2, but still
  reasonable)
- florence prety good as well
- uform much slower than other captioning models
- bunny, joy caption & molmo good if you can keep them warm

### txt2img

- sdxl warm, flux & sd warm
- kandinsky & proteus not necessarily warm, but quick

### txt2txt

- meta llamas both usually warm, both quick

### txt2audio

- riffusion warm & pretty quick
- stable audio open not so warm, but quick
- musicgen takes ages
