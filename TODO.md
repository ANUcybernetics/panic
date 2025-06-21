# Panic TODO

## NIME blockers

- see if archiving (in tests) can be simplified
- update all tests to use the new network runner testing approach
- check if a catch all handler needs to be added to NetworkRunner
- find out why the live cards aren't showing :invoking or :failed invocations
- ensure the vestaboard delays are still appropriate
- check that time-based QR code -> terminal workflow works for non-logged-in
  users (perhaps only required for installations, and also requires real
  deployment to test properly)
- investigate the "Sizes of tensors must match except in dimension 0" error from
  Riffusion (check the params I'm sending are correct)
- add [this](https://replicate.com/zsxkib/flux-music), and maybe
  <https://replicate.com/ardianfe/music-gen-fn-400e?prediction=kpjdayh931rma0cqj3cbyv0p8c>
- get FitText hook working
- add UI for configuring network lockout timer duration
- find one (or a few) good text audio networks to use at NIME
- load it on to some RPis
- set up real NIME installations
- add "back off over time logic" based on time

## network ideas

- musicgen and gemini flash (even flash-lite for more crappiness and fun)
- one of the ones with lyrics, plus whisper

## important/quality-of-life

- fix flaky tests
- nicer visuals (no green bg?) for audio cards
- maybe rename PanicWeb.InvocationWatcher (now that there's a Watcher module) to
  WatcherLive or something similar
- make sure vestaboards crashing doesn't bring down the whole thing
- create a new `Display` domain or similar (because Installations and Watchers
  shouldn't really be in `Engine`)
- add installations section to user live view (not standalone)
- add auth for installations (via network.user) or check if it's there already

## thought bubbles

- update to tailwind 4.0, and use the text shadow stuff (actually this might
  happen with Phoenix 1.8)
- add the ability to specify multiple offsets for single screen view
- show multiple invocations in info view
- why aren't <p>s geting margins in prose blocks in info view?
- refocus and clear the model select component on selection (to allow for
  rapid-fire adding of models) or perhaps even replace with
  [this if it's better](https://hexdocs.pm/autocomplete_input/readme.html)
- model view (w/hand-written description)
- store invocation metadata (also add burn rate for a given network)
- make unauthenticated login not forget which page you were going to
- now that models is an array, have them Enum.each through, but put an await so
  they're all done (this will make the Vestaboard-wait period better; it won't
  wait if the time has already elapsed)
- refactor models (and tokens) to just be boring has_many/belongs_to
  relationships, rather than arrays
- make regular backups of the sqlite db file (inc. a way to restore from them,
  for changing machines)
- have a "pre-warm all network models" option, which would fire off one for all
  models at startup
- update instead of hosting the nsfw placeholder and audio waveform pictures on
  tigris, serve them from priv/static/images (the files are already in there)
- a "waiting" timer on all pending invocations (better still, with feedback for
  e.g. replicate on what the actual status was)
- replace the "split into `<p>`s based on double newline with proper md parsing
- add an indicator to the model select component to say a) if the network has
  been saved b) if it's runnable c) if it's currently running
- flesh out the tests to make sure the authorisation policies work properly
  (mostly adding "negative versions" of current positive tests)
- add a "restart from invocation" UI option
- add cost/credit balance lookup stuff to the user UI
- git cleanup: tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at
  AusCyber, v2 is Birch install)
- add oblique strategies model (GPT-4 powered)
- add presence to network views so that it'll say how many people are watching a
  particular network
- add video support (maybe... need to figure out how to handle video inputs as
  well)

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
