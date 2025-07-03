# Panic TODO

- update deps (maybe a PR for phoenix_test/floki?)
- check if the autocomplete_input js lib needs to be installed (as per README)
- check if the live_select is still needed (and why the FocusInput is there?)
- alternatively to the last two... maybe go back to LiveSelect? idk
- long-running debug (w/sound) on the commbox
- add the "restart on error" logic (because it's better than the alternative)

## quality-of-life

- have a QR code that points to the model's "about" page on all installation
  displays (bottom RH corner)
- named watchers, and use those as map keys rather than array position index
  (and make them editable... perhaps with pubsub updates)
- check that time-based QR code -> terminal workflow works for non-logged-in
  users (perhaps only required for installations, and also requires real
  deployment to test properly)
- make sure vestaboards crashing doesn't bring down the whole thing
- create a new `Display` domain or similar (because Installations and Watchers
  shouldn't really be in `Engine`)
- add an image->image flux model (and perhaps a way to still kick it off with
  text)

## thought bubbles

- write the vis in webgl (or use the current package, but randomize between a
  few different [styles](https://audiomotion.dev/demo/))
- don't have api tokens per-user, have them as a standalone resource which can
  have many users (and also could be set as "default" for requests using the
  rolling QR code terminal)
- update to tailwind 4.0, and use the text shadow stuff (actually this might
  happen with Phoenix 1.8)
- honestly, it's looking less likely that this will be a "multi-user SaaS thing"
  and more like I'll always be tweaking it and making bespoke changes for our
  specific purposes... so perhaps remove the auth/policy stuff in general
- add the ability to specify multiple offsets for single screen view
- show multiple invocations in info view
- why aren't <p>s geting margins in prose blocks in info view?
- refocus and clear the model select component on selection (to allow for
  rapid-fire adding of models) or perhaps even replace with
  [this if it's better](https://hexdocs.pm/autocomplete_input/readme.html)
- model view (w/hand-written description)
- store invocation metadata (also add burn rate for a given network)
- make unauthenticated login not forget which page you were going to
- refactor models to just be boring has_many/belongs_to relationships, rather
  than arrays
- make regular backups of the sqlite db file (inc. a way to restore from them,
  for changing machines)
- have a "pre-warm all network models" option, which would fire off an API call
  for all models at startup
- for nsfw, dynamically generate the replacement image
- add an indicator to the model select component to say a) if the network has
  been saved b) if it's runnable c) if it's currently running
- add a "restart from invocation" UI option
- add cost/credit balance lookup stuff to the user UI
- git cleanup: tidy up v2/v3 nomenclature (probably: v0 is prototype, v1 at
  AusCyber, v2 is Birch install)
- add video support (maybe... need to figure out how to handle video inputs as
  well)

## NIME install notes

- soad foyer LH is #0, RH is #1
- #2 is in kambri foyer (double-check this)

## figure this out

2025-06-27T07:11:49Z app[e78432edcd9248] syd [info]07:11:49.720 [error]
GenServer #PID<0.197927.0> terminating 2025-06-27T07:11:49Z app[e78432edcd9248]
syd [info]** (KeyError) key :data not found in: %{seconds_remaining: 30}
2025-06-27T07:11:49Z app[e78432edcd9248] syd [info] (panic 3.0.0-beta.0)
lib/panic_web/live/admin_live.ex:82: PanicWeb.AdminLive.handle_info/2
2025-06-27T07:11:49Z app[e78432edcd9248] syd [info] (phoenix_live_view 1.0.17)
lib/phoenix_live_view/channel.ex:360: Phoenix.LiveView.Channel.handle_info/2
2025-06-27T07:11:49Z app[e78432edcd9248] syd [info] (stdlib 6.2.2)
gen_server.erl:2345: :gen_server.try_handle_info/3 2025-06-27T07:11:49Z
app[e78432edcd9248] syd [info] (stdlib 6.2.2) gen_server.erl:2433:
:gen_server.handle_msg/6 2025-06-27T07:11:49Z app[e78432edcd9248] syd [info]
(stdlib 6.2.2) proc_lib.erl:329: :proc_lib.init_p_do_apply/3
2025-06-27T07:11:49Z app[e78432edcd9248] syd [info]Last message:
%Phoenix.Socket.Broadcast{topic: "invocation:11", event: "lockout_countdown",
payload: %{seconds_remaining: 30}} 2025-06-27T07:11:51Z app[e78432edcd9248] syd
[info]07:11:51.724 [error] GenServer #PID<0.197961.0> terminating
2025-06-27T07:11:51Z app[e78432edcd9248] syd [info]** (KeyError) key :data not
found in: %{seconds_remaining: 28} 2025-06-27T07:11:51Z app[e78432edcd9248] syd
[info] (panic 3.0.0-beta.0) lib/panic_web/live/admin_live.ex:82:
PanicWeb.AdminLive.handle_info/2 2025-06-27T07:11:51Z app[e78432edcd9248] syd
[info] (phoenix_live_view 1.0.17) lib/phoenix_live_view/channel.ex:360:
Phoenix.LiveView.Channel.handle_info/2 2025-06-27T07:11:51Z app[e78432edcd9248]
syd [info] (stdlib 6.2.2) gen_server.erl:2345: :gen_server.try_handle_info/3
2025-06-27T07:11:51Z app[e78432edcd9248] syd [info] (stdlib 6.2.2)
gen_server.erl:2433: :gen_server.handle_msg/6 2025-06-27T07:11:51Z
app[e78432edcd9248] syd [info] (stdlib 6.2.2) proc_lib.erl:329:
:proc_lib.init_p_do_apply/3 2025-06-27T07:11:51Z app[e78432edcd9248] syd
[info]Last message: %Phoenix.Socket.Broadcast{topic: "invocation:11", event:
"lockout_countdown", payload: %{seconds_remaining: 28}} 2025-06-27T07:11:53Z
app[e78432edcd9248] syd [info]07:11:53.728 [error] GenServer #PID<0.197969.0>
terminating 2025-06-27T07:11:53Z app[e78432edcd9248] syd [info]\*\* (KeyError)
key :data not found in: %{seconds_remaining: 26} 2025-06-27T07:11:53Z
app[e78432edcd9248] syd [info] (panic 3.0.0-beta.0)
lib/panic_web/live/admin_live.ex:82: PanicWeb.AdminLive.handle_info/2
2025-06-27T07:11:53Z app[e78432edcd9248] syd [info] (phoenix_live_view 1.0.17)
lib/phoenix_live_view/channel.ex:360: Phoenix.LiveView.Channel.handle_info/2
2025-06-27T07:11:53Z app[e78432edcd9248] syd [info] (stdlib 6.2.2)
gen_server.erl:2345: :gen_server.try_handle_info/3 2025-06-27T07:11:53Z
app[e78432edcd9248] syd [info] (stdlib 6.2.2) gen_server.erl:2433:
:gen_server.handle_msg/6 2025-06-27T07:11:53Z app[e78432edcd9248] syd [info]
(stdlib 6.2.2) proc_lib.erl:329: :proc_lib.init_p_do_apply/3
2025-06-27T07:11:53Z app[e78432edcd9248] syd [info]Last message:
%Phoenix.Socket.Broadcast{topic: "invocation:11", event: "lockout_countdown",
payload: %{seconds_remaining: 26}}
