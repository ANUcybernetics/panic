# Vestaboard-handling refactoring plan

Fundamentally, the vestaboards are just a type of "watcher" - they display (in
real time) the action of a given NetworkRunner, but they don't do anything
critical to the operation of the system. Currently, though, the vestaboard
handling code (in particular the Invocation resource's `invoke` action)

A much-improved architecture would be to:

- remove all vestaboard-handling code from Invocation resource (which would also
  mean that `:about_to_invoke` would simplify to just
  `change set_attribute(:state, :invoking)`)
- the Network :models attribute can be just an array of strings (model names),
  not the current nested `{:array, {:array, :string}}`
- related to that, all the `model_ids_to_model_list` and related code (including
  a bunch of stuff in the PanicWeb.NetworkLive.Info module) could be simplified

Instead, the vestaboard watchers could all be handled by the NetworkRunner:

- when a run is started, pull the array of watchers from the
  network.installation.watchers and filter to only those that are vestaboard
  watchers
- each time an invocation is completed, check for any relevant vestaboard
  watchers (based on the sequence number of the invocation) and if so, call the
  Vestaboard.send_text function to trigger the call to the vestaboard API

Ensure all relevant tests are updated and that `mix test` passes at the end of
the refactoring process.

Most of these changes should make things simpler and clearer in the code - if
there are any changes which would complicate the codebase, check with me first.
