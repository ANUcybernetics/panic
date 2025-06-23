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

## Real-time Updates with InvocationWatcher

The **InvocationWatcher** module
([`lib/panic_web/live/invocation_watcher.ex`](lib/panic_web/live/invocation_watcher.ex))
provides real-time invocation updates across LiveViews through Phoenix PubSub:

- **on_mount hook**: Configured in the router for authenticated and optional
  authentication sessions, automatically subscribes LiveViews to the
  `"invocation:<network_id>"` topic
- **Stream management**: Maintains an `:invocations` stream that updates
  whenever new invocations are created or existing ones change state
- **Display modes**: Supports two rendering patterns:
  - `{:grid, rows, cols}` - Shows multiple invocations in a grid layout
  - `{:single, offset, stride, show_invoking}` - Shows one invocation at a time,
    updating based on sequence number matching (sequence % stride == offset).
    The `show_invoking` boolean controls whether invocations in the `:invoking`
    state are displayed (true) or filtered out (false). Backward compatibility
    is maintained with 3-element tuples which default to `show_invoking: false`.
- **Automatic handling**: Once mounted, LiveViews receive invocation broadcasts
  without any boilerplate - the watcher attaches a `handle_info` callback that
  processes updates

In practice, this enables features like:

- Live terminal displays showing the current invocation output
- Grid views displaying multiple recent invocations
- Installation watchers that update physical displays (Vestaboards) in real-time
- Synchronized updates across all connected clients viewing the same network

The Invocation resource publishes all updates via Ash's pub_sub configuration,
ensuring any state change (from creation through completion) is broadcast to
subscribed LiveViews.

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
