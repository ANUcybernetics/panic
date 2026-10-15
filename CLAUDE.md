# PANIC! codebase guide

PANIC! runs chains of generative AI models end to end (each output is the next
model's input) and shows the outputs on web displays and Vestaboards in real
time. It's an Ash + Phoenix LiveView app on SQLite. The domain glossary
(network, invocation, run, watcher, installation) is in `README.md`.

## Layout

- `Panic.Engine` --- `Network` (an ordered list of model ids, owned by a user)
  and `Invocation` (one model call: input, output, state, sequence number)
- `Panic.Model` --- the models, defined in code rather than the database
  because each needs bespoke code to call its platform and parse the result.
  Platforms (`lib/panic/platforms/`) implement `invoke(model, input, token)`;
  `Panic.Platforms.Dummy` needs no API token, so use `dummy-*` models in tests
- `Panic.Watcher` --- `Installation`, a set of watcher configs (grid, single,
  vestaboard) for a network's displays
- `Panic.Accounts` --- users and API tokens (AshAuthentication)
- `PanicWeb.WatcherSubscriber` --- LiveView `on_mount` hook that subscribes to a
  network's broadcasts, tracks presence and maintains the `:invocations` stream

## How a run works

Run state lives in the database: `Network.current_run_number` (nil when idle)
and each invocation's `state` and `invoke_after`. The `Panic.Engine.Invocation`
moduledoc describes the flow; in short:

- `Invocation :start_run` checks the lockout, creates the genesis invocation
  and schedules the `:invoke` AshOban trigger at `invoke_after`
- invoking emits signals from `Panic.Engine.Signals`, and listeners in
  `signals_in` sections do the rest: the next invocation (inline), ending a
  failed run (inline), archiving and Vestaboards (Oban jobs)
- the trigger only runs while its invocation is in the network's current run,
  so stopping or replacing a run is just updating the network
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

## Development

- tidewave is connected to the running dev server: use `project_eval` to
  interrogate it and never start or stop the Phoenix server yourself
- never call `Mix.env()` in application code (it doesn't exist in releases)
- after changes, `mix compile --warnings-as-errors` and `mix test`; CI also
  checks `mix format`
- releases migrate on boot (`Panic.Application`), so migrations must be safe
  to run against the production database as-is

`rpi/` holds the Raspberry Pi kiosk scripts for physical displays (see
`rpi/README.md`).

# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the
packages listed below. Before attempting to use any of these packages or to
discover if you should use them, review their usage rules to understand the
correct patterns, conventions, and best practices.

<!-- usage-rules-header-end -->

<!-- ash_authentication-start -->
## ash_authentication usage
_Authentication extension for the Ash Framework._

@deps/ash_authentication/usage-rules.md
<!-- ash_authentication-end -->

<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

@deps/igniter/usage-rules.md
<!-- igniter-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
@deps/usage_rules/usage-rules/elixir.md
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
@deps/usage_rules/usage-rules/otp.md
<!-- usage_rules:otp-end -->
<!-- ash_phoenix-start -->
## ash_phoenix usage
_Utilities for integrating Ash and Phoenix_

@deps/ash_phoenix/usage-rules.md
<!-- ash_phoenix-end -->
<!-- ash-start -->
## ash usage
_A declarative, extensible framework for building Elixir applications._

@deps/ash/usage-rules.md
<!-- ash-end -->
<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

@deps/usage_rules/usage-rules.md
<!-- usage_rules-end -->
<!-- mdex-start -->
## mdex usage
_Fast and extensible Markdown for Elixir_

@deps/mdex/usage-rules.md
<!-- mdex-end -->
<!-- usage-rules-end -->
