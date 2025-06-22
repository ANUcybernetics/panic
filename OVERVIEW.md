# PANIC! Architecture Overview

PANIC! is an interactive AI playground built with Elixir, Ash Framework, and
Phoenix LiveView that allows users to create feedback loops of generative AI
models.

## Core Concepts

### Ash Resources

The app is built on two primary Ash resources:

- **Network** ([`lib/panic/engine/network.ex`](lib/panic/engine/network.ex)):
  Represents a cyclic graph of AI models where outputs feed into subsequent
  inputs. Each network has an ordered array of model IDs, a lockout period
  between runs, and belongs to a user.

- **Invocation**
  ([`lib/panic/engine/invocation.ex`](lib/panic/engine/invocation.ex)):
  Represents a single AI model inference run, containing input prompt, output
  prediction, state (ready/invoking/completed/failed), and sequence number
  within a run.

## NetworkRunner Architecture

The **NetworkRunner** GenServer
([`lib/panic/engine/network_runner.ex`](lib/panic/engine/network_runner.ex))
orchestrates the continuous execution of networks:

- Acts as a state machine with `idle` (no active run) and `running` (processing
  invocations) states
- Creates invocations recursively: when one completes, it prepares the next
  using the previous output as input
- Enforces lockout periods between runs to prevent overwhelming the system
- Processes invocations asynchronously via Task.Supervisor to avoid blocking
- Dispatches outputs to external displays (Vestaboards) and archives multimedia
  content

Each network gets its own NetworkRunner process, dynamically supervised and
registered in the NetworkRegistry.

## Model System

Models are defined in [`lib/panic/model.ex`](lib/panic/model.ex) as structs
containing:

- Basic metadata (id, name, platform, input/output types)
- An `:invoke` function that handles platform-specific API calls and response
  parsing

Rather than storing models in the database, they're defined in code because each
requires bespoke logic to marshal inputs/outputs. The module provides helper
functions like `by_id/1` and `all/1` for querying available models.

Platforms supported include OpenAI, Replicate, Gemini, and a Dummy platform for
testing.

## User Interface

The web interface ([`lib/panic_web/router.ex`](lib/panic_web/router.ex)) uses
Phoenix LiveView with two authentication contexts:

- **Authenticated users** can create/manage networks and installations, view
  admin panels
- **Anonymous users** can view network terminals, displays, and installation
  watchers

Key LiveViews include:

- Network management and configuration
- Terminal interface for interacting with running networks
- Various display modes for viewing invocation outputs
- Installation management for configuring external displays

## Testing Strategy

The test suite employs several patterns:

- **NetworkRunner cleanup**: Tests call
  `PanicWeb.Helpers.stop_all_network_runners/0` in setup to prevent process
  persistence issues
- **Sync mode**: Tests enable synchronous NetworkRunner execution to avoid async
  timing issues
- **Fixtures**: Common test data creation helpers in `Panic.Fixtures`
- **Actor context**: Tests carefully manage Ash actor context to avoid
  authorization errors

While the codebase mentions property-based testing with ExUnitProperties and
Ash.Generator, the current implementation primarily uses traditional
example-based tests.
