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
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark. 
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, us `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

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

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

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
