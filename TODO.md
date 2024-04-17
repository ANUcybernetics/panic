# Panic TODO

- add Oban
- slim down the set of actions
- transfer all resources from the notebook
- tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at AusCyber, v2 is Birch install)
- mock the test stubs as per that dashbit blog post
- put all the identities/unique constraints in
- update the vestaboard stuff to use the new read/write API (which will simplify things)

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
