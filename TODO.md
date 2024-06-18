# Panic TODO

- fill out the suite of actions, including tests
- get the platform modules to pull API keys from the user
- upgrade to liveview 1.0-rc
- put a frontend on 'er
- add nice Ash.Errors (Splode) errors for the different AI platform call failure modes
- tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at AusCyber, v2 is Birch install)
- put all the identities/unique constraints in
- set up tigris to host the images (because replicate outputs now expire in 1h)
- add embeddings for all outputs (possibly via an ash oban trigger)
- audio vis (with [this](https://audiomotion.dev/demo/multi.html), or something else

### bugfixes

- the `Engine.create_network` code interface takes a `:description` arg, which is optional on the resource, but required on the code interface... there's gotta be a nicer way to do that

## old v2 items

- [ ] remove APIToken as separate resource (add a has_many embed to user, managed via user controller)
- [ ] use embeds + cast_assoc, hidden form fields,streams; IOW phoenix it properly
- [ ] Vestaboard module isn't like the others, and should be separated (maybe)
- [ ] ability to use pinned replicate models (maybe even to request the pin)
- [ ] no need for "unauthenticated" route for terminal
- [ ] use the new finitomata test helpers
- [ ] add `admin` field to User
- [ ] add `status` field to Prediction
- [ ] add (virtual) I/O type to Prediction
- [ ] add user profile liveview
- [ ] create `Prediction` on form submit, not just when the API call returns
- [ ] add new views as per the notebook sketches
- [ ] in add model modal, group models by input type
