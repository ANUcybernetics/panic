# Panic TODO

- create ApiToken resource, remove attribute from user
- fill out the suite of actions, including tests
- get the platform modules to pull API keys from the user
- upgrade to liveview 1.0-rc
- put a frontend on 'er (adding views as per the notebook sketches)
- add nice Ash.Errors (Splode) errors for the different AI platform call failure
  modes
- tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at AusCyber, v2 is
  Birch install)
- put all the identities/unique constraints in
- set up tigris to host the images (because replicate outputs now expire in 1h)
- add embeddings for all outputs (possibly via an ash oban trigger)
- audio vis (with [this](https://audiomotion.dev/demo/multi.html), or something
  else
- add QR code function component
- add rolling cookie/URL param to QR code
- add "slow down over time" (and scheduling) logic to runs
- when viewing a grid for a running network, initially pull the latest
  @num_grid_slots from the db (based on :genesis_id) and pre-populate the grid
  slots
- write model descriptions
- test that access control works for the network & prediction
- add network permalinks (look in the history - there's some deleted `router.ex`
  code in there)
- add oblique strategies model (GPT-4 powered)
- clear the terminal input when a new prediction is triggered (well, actually
  it's
  [this issue](https://github.com/phoenixframework/phoenix_live_view/issues/624),
  so maybe not worth getting bogged down on)
- add user profile liveview

### bugfixes

- the `Engine.create_network` code interface takes a `:description` arg, which
  is optional on the resource, but required on the code interface... there's
  gotta be a nicer way to do that

### Other Setup notes

```
mix phx.gen.context Models Run runs platform:enum:replicate:huggingface:openai model_name:string input:string output:string metadata:map
mix phx.gen.live Runs Prediction predictions input:string metadata:map model:string output:string run_index:integer network_id:references:networks genesis_id:references:predictions
```
