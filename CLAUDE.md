# PANIC! codebase guide

PANIC! is an interactive AI playground built with Elixir, Ash Framework, and Phoenix LiveView. It allows users to create feedback loops of generative AI models.

For a comprehensive architectural overview, see @OVERVIEW.md

## Project structure

### Core domains (Ash)

- **Panic.Engine** (`lib/panic/engine.ex`) - orchestrates network execution
  - `Panic.Engine.Network` (`lib/panic/engine/network.ex`) - represents a cyclic graph of AI models
  - `Panic.Engine.Invocation` (`lib/panic/engine/invocation.ex`) - represents a single AI model inference run
  - `Panic.Engine.NetworkRunner` (`lib/panic/engine/network_runner.ex`) - GenServer that orchestrates continuous execution of networks
  - `Panic.Engine.NetworkSupervisor` (`lib/panic/engine/network_supervisor.ex`) - DynamicSupervisor for NetworkRunner processes
  - `Panic.Engine.Archiver` (`lib/panic/engine/archiver.ex`) - handles multimedia content archiving to S3

- **Panic.Accounts** (`lib/panic/accounts/`) - user management and authentication
  - `Panic.Accounts.User` (`lib/panic/accounts/user.ex`) - user resource with AshAuthentication
  - `Panic.Accounts.ApiToken` (`lib/panic/accounts/api_token.ex`) - API token authentication
  - Uses `ash_authentication` for password and API key strategies

- **Panic.Watcher** (`lib/panic/watcher.ex`) - manages installations and display configurations
  - `Panic.Watcher.Installation` (`lib/panic/watcher/installation.ex`) - represents physical/virtual display installations
  - `Panic.Watcher.Installation.Config` (`lib/panic/watcher/installation/config.ex`) - embedded display configuration

### Models and platforms

- **Panic.Model** (`lib/panic/model.ex`) - defines available AI models (stored in code, not database)
  - Each model has `id`, `platform`, `input_type`, `output_type`, and an `invoke` function
  - Models are defined as structs because each requires bespoke logic for API calls

- **Platforms** (`lib/panic/platforms/`) - platform-specific API integrations
  - `Panic.Platforms.OpenAI` - OpenAI API (GPT models, DALL-E, TTS, Whisper)
  - `Panic.Platforms.Replicate` - Replicate API (various open-source models)
  - `Panic.Platforms.Gemini` - Google Gemini API
  - `Panic.Platforms.Vestaboard` - Vestaboard split-flap display API
  - `Panic.Platforms.Dummy` - test platform for development

### Web interface

- **PanicWeb** (`lib/panic_web/`) - Phoenix LiveView interface
  - `PanicWeb.Router` (`lib/panic_web/router.ex`) - defines authenticated and anonymous routes
  - `PanicWeb.WatcherSubscriber` (`lib/panic_web/live/watcher_subscriber.ex`) - provides real-time invocation updates via Phoenix PubSub and tracks viewers via Phoenix Presence
  - `PanicWeb.Presence` (`lib/panic_web/presence.ex`) - tracks who is watching each network

- **LiveViews** (`lib/panic_web/live/`)
  - `NetworkLive.Show` - network management and configuration
  - `NetworkLive.Terminal` - terminal interface for running networks
  - `NetworkLive.Display` - various display modes for viewing invocations
  - `InstallationLive.*` - installation management for external displays

### OTP processes

- **NetworkRegistry** - Registry for NetworkRunner GenServers (keys: network_id)
- **NetworkSupervisor** - DynamicSupervisor for NetworkRunner processes
- **TaskSupervisor** - Task.Supervisor for async invocation processing
- **Presence** - Phoenix Presence for tracking connected viewers

### Testing

- **Test support** (`test/support/`)
  - `Panic.Fixtures` - fixture creation using generators
  - `Panic.Generators` - StreamData generators for property-based testing
  - `PanicWeb.Helpers` - test helpers including NetworkRunner cleanup
  - `Panic.Test.ArchiverPatches` - patches to avoid real file downloads in tests
  - `Panic.Test.ExternalApiPatches` - patches for external API calls

- **Test patterns**
  - Use `PanicWeb.Helpers.stop_all_network_runners/0` in setup to prevent process persistence
  - Many tests run with `async: false` due to SQLite's single-writer limitation and shared NetworkRegistry
  - Use globally unique values for identity attributes to prevent deadlocks
  - Enable sync mode for NetworkRunner in tests to avoid async timing issues

## Development environment

This project uses `mise` for tool version management (see `.mise.toml`). Always prefix commands with `mise exec --` to ensure the correct Elixir/Erlang versions are used (e.g. `mise exec -- mix test`).

## Development workflow

- use `@moduledoc` and `@doc` attributes to document your code (including examples which can be doctest-ed)
- use tidewave MCP tools when available to interrogate the running application
- use the `project_eval` tool to execute code in the running instance - eval `h Module.fun` for documentation
- use the `package_docs_search` and `get_docs` tools to find library documentation
- prefer using LiveView instead of regular Controllers
- once you are done with changes, run `mix compile` and fix any issues
- write tests for your changes and ALWAYS run `mix test` afterwards
- use `ExUnitProperties` for property-based testing and `use Ash.Generator` to create seed data
- in tests, don't require exact matches of error messages - raising the right type of error is enough
- use `list_generators` to list available generators, otherwise `mix help`
- if you have to run generator tasks, pass `--yes` and always prefer to use generators as a basis for code generation, then modify afterwards
- always use Ash concepts, almost never ecto concepts directly
- when creating new Ash resources/validations/changes/calculations, use proper module-based versions, and use the appropriate generator (e.g. `mix ash.gen.resource` or `mix ash.gen.change`)
- never attempt to start or stop a phoenix application as your tidewave tools work by being connected to the running application
- do not ever call Mix.env() in application code, because Mix is not available in prod and this will cause a crash

## Common patterns

### Network execution flow

1. User creates a Network with an ordered array of model IDs
2. NetworkRunner GenServer starts for that network
3. NetworkRunner creates Invocations recursively:
   - Creates first invocation with initial prompt via `:prepare_first` action
   - Processes invocation asynchronously via Task.Supervisor
   - Creates next invocation using previous output via `:prepare_next` action
   - Enforces lockout period between runs
4. Invocations broadcast updates via Ash pub_sub
5. WatcherSubscriber receives broadcasts and updates LiveViews
6. Archiver downloads and stores multimedia content to S3

### Adding a new platform

1. Create module in `lib/panic/platforms/`
2. Implement `invoke/3` function that takes model path, input, and API token
3. Add platform-specific models to `Panic.Model.all/0`
4. Add API credentials to secrets management

### Adding a new model

1. Add model struct to `Panic.Model.all/0`
2. Define `invoke` function that handles platform-specific API calls
3. Ensure input/output types are correctly specified
4. Test with a simple network

## Raspberry Pi deployment

This repo includes raspberry pi config scripts in `rpi/` for running PANIC! on Raspberry Pi devices. For documentation on the latest raspbian (which these scripts use), see https://www.raspberrypi.com/documentation/computers/os.html

## Architectural notes

- Models are defined in code (not database) because each requires bespoke logic to marshal inputs/outputs
- NetworkRunner processes are dynamically supervised and registered in NetworkRegistry
- Real-time updates use Phoenix PubSub (Invocation resource has `notifiers: [Ash.Notifier.PubSub]`)
- Phoenix Presence tracks who is watching each network to optimize broadcasts
- SQLite database with Ecto SQL Sandbox for test isolation
- Tests increase SQLite busy_timeout to 5000ms to reduce lock conflicts

<-- usage-rules-start --> <-- ash_phoenix-start -->

## ash_phoenix usage

[ash_phoenix usage rules](deps/ash_phoenix/usage-rules.md) <-- ash_phoenix-end
--> <-- ash_authentication-start -->

## ash_authentication usage

[ash_authentication usage rules](deps/ash_authentication/usage-rules.md) <--
ash_authentication-end --> <-- igniter-start -->

## igniter usage

[igniter usage rules](deps/igniter/usage-rules.md) <-- igniter-end --> <--
ash_ai-start -->

## ash_ai usage

[ash_ai usage rules](deps/ash_ai/usage-rules.md) <-- ash_ai-end --> <--
ash-start -->

## ash usage

[ash usage rules](deps/ash/usage-rules.md) <-- ash-end --> <-- usage-rules-end
-->

<!-- usage-rules-start -->
<!-- usage-rules-header -->

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
<!-- ash_ai-start -->
## ash_ai usage
_Integrated LLM features for your Ash application._

@deps/ash_ai/usage-rules.md
<!-- ash_ai-end -->
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
