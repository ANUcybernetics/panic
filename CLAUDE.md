# PANIC! codebase guide

PANIC! runs chains of generative AI models end to end (each output is the next
model's input) and shows the outputs on web displays and Vestaboards in real
time. It's an Ash + Phoenix LiveView app on SQLite. The domain glossary
(network, invocation, run, watcher, installation) is in `README.md`.

## Layout

- `Panic.Engine` --- `Network` (an ordered list of model ids, owned by a user)
  and `Invocation` (one model call: input, output, state, sequence number)
- `Panic.Model` --- the models, defined in code rather than the database because
  each needs bespoke code to call its platform and parse the result. Platforms
  (`lib/panic/platforms/`) implement `invoke(model, input, token)`;
  `Panic.Platforms.Dummy` needs no API token, so use `dummy-*` models in tests
- `Panic.Watcher` --- `Installation`, a set of watcher configs (grid, single,
  vestaboard) for a network's displays
- `Panic.Accounts` --- users (AshAuthentication; no self-registration, see
  `Panic.Release.create_user_from_env/0`), `PlatformCredentials` (the one
  app-wide row of platform and Vestaboard keys, AshCloak-encrypted, admin-only)
  and `ApiKey` (admins' keys for the JSON API)
- `PanicWeb.WatcherSubscriber` --- LiveView `on_mount` hook that subscribes to a
  network's broadcasts, tracks presence and maintains the `:invocations` stream
- JSON API --- `ash_json_api` routes are declared in the `json_api` blocks of
  the `Panic.Engine` and `Panic.Watcher` domains; `PanicWeb.ApiAuth` limits it
  to admins. A resource attribute only appears in the API if it's `public? true`

## How a run works

Run state lives in the database: `Network.current_run_number` (nil when idle)
and each invocation's `state` and `invoke_after`. The `Panic.Engine.Invocation`
moduledoc describes the flow; in short:

- `Invocation :start_run` checks the lockout, creates the genesis invocation and
  schedules the `:invoke` AshOban trigger at `invoke_after`
- invoking emits signals from `Panic.Engine.Signals`, and listeners in
  `signals_in` sections do the rest: the next invocation (inline), ending a
  failed run (inline), archiving and Vestaboards (Oban jobs)
- the trigger only runs while its invocation is in the network's current run, so
  stopping or replacing a run is just updating the network
- timing and Vestaboard rules are pure functions in `Panic.Engine.Schedule` and
  `Panic.Watcher.Vestaboards`

Keep side effects of a run in signal listeners rather than in the engine's
changes. Model calls happen in `before_transaction` because they can take
minutes and SQLite has a single writer.

Oban uses the Lite engine on the same repo, so jobs enqueued inside an action
commit or roll back with it. Ash write actions run in `BEGIN IMMEDIATE`
transactions (`Panic.Repo.write_transactions?/0`).

## Testing

- Oban runs in `:manual` mode: a run only advances when a test drains a queue
  with `Panic.EngineHelpers` (e.g. `run_next_invocation/0`)
- tests touching the database mostly run `async: false` (SQLite single writer)
- `Repatch.ExUnit` resets patches per test, including the global archiver
  patches from `test_helper.exs`; reapply them with
  `Panic.Test.ArchiverPatches.apply_patches/0` where archive jobs run
- give identity attributes unique values (see the Ash usage rules)
- API tests use `PanicWeb.ApiHelpers` (`admin_with_api_key/0`, `api_conn/1`)

## Development

- the dev server (`mix phx.server`, port 4010) hosts tidewave; start it in the
  background if it isn't running, and leave it running if you didn't start it
- every environment but test needs `PANIC_CLOAK_KEY` (see `config/runtime.exs`);
  in dev it lives in the untracked `mise.local.toml`, so run mix through
  `mise exec --`
- never call `Mix.env()` in application code (it doesn't exist in releases)
- CI runs `mix compile --warnings-as-errors`, `mix format --check-formatted` and
  `mix test`
- releases migrate on boot (`Panic.Application`), so migrations must be safe to
  run against the production database as-is
- pushing `main` deploys to Fly (`.github/workflows/fly-deploy.yml`), so set any
  new secret (`fly secrets set`) before pushing code that needs it

`rpi/` holds the Raspberry Pi kiosk scripts for physical displays (see
`rpi/README.md`).

<!-- usage-rules-start -->
<!-- usage_rules-start -->

## usage_rules usage

_A config-driven dev tool for Elixir projects to manage AGENTS.md files and
agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should _thoroughly_ consult before
taking any action. These usage rules contain guidelines and rules _directly from
the package authors_. They are your best source of knowledge for making
decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the
current project, or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```

## Searching Documentation

You should also consult the documentation of any tools you are using, early and
often. The best way to accomplish this is to use the `usage_rules.search_docs`
mix task. Once you have found what you are looking for, use the links in the
search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```

<!-- usage_rules-end -->
<!-- usage-rules-end -->
