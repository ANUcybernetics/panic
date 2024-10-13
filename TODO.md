# Panic TODO

- find out why grid display is only showing 6 invocations
- see why links to replicate-hosted webps get downloaded (target blank or
  something?)
- come up with some cool networks, write descriptions, _test them_
- unplug the network and see how gracefully it fails
- make screen recording for backup purposes
- refocus and clear the model select component on selection (to allow for
  rapid-fire adding of models)
- add stop all button to admin view

## SXSW network plan

1. Rapid-fire Images and Words: text-to-image and back (vanilla-ish, but
   multiple models, though)
2. Cocktail Party Problem: multilingual speech
3. Finetune Friday: all the flux loras
4. Rube Goldberg Machine: stable audio, whisper, images, with some LLM help

- maybe one which adds the specifics back in (e.g. instead of just "people",
  describe specific people or things)

### model notes

#### img2txt

- blips good, usually warm (3 takes slightly longer than 2, but still
  reasonable)
- florence prety good as well
- uform much slower than other captioning models
- bunny, joy caption & molmo good if you can keep them warm

#### txt2img

- sdxl warm, flux & sd warm
- kandinsky & proteus not necessarily warm, but quick

#### txt2txt

- meta llamas both usually warm, both quick

#### txt2audio

- riffusion warm & pretty quick
- stable audio open not so warm, but quick
- musicgen takes ages

## mac mini

- paint Enter key on keyboard?
- set up desktop bg (launch panic script, WT folder)
- test with speaker

## for v2 proper, but not (necessarily) for SXSW

- model view
- store invocation metadata
- make unauthenticated login not forget which page you were going to
- add embeddings for all outputs (another Oban worker)
- add HUD or other vis for the embedding trajectories
- TDA code

## ideas (not necessarily TODO, but y'know...)

- download sqlite file as backup
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
