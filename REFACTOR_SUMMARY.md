# Refactoring Summary: Oban to GenServer Migration

## Overview

This refactor replaced the Oban-based job queue system for processing AI model
invocations with a GenServer-based approach. The new system is simpler, more
direct, and takes better advantage of Elixir's built-in concurrency primitives.

## Key Changes

### 1. Removed Dependencies

- Removed `oban` and `ash_oban` from `mix.exs`
- Removed Oban configuration from:
  - `config/config.exs`
  - `config/runtime.exs`
  - `config/test.exs`

### 2. New GenServer Architecture

#### Created New Modules

- **`Panic.Engine.NetworkProcessor`** - A GenServer that handles invocation
  processing for a specific network
- **`Panic.Engine.NetworkSupervisor`** - A DynamicSupervisor that manages
  NetworkProcessor GenServers
- **`Panic.Engine.NetworkRegistry`** - A Registry for looking up
  NetworkProcessor GenServers by network ID

#### Key Features of NetworkProcessor

- Handles recursive invocation processing
- Enforces 30-second lockout period between genesis invocations
- Archives image/audio outputs to S3-compatible storage
- Supports graceful cancellation of running invocations
- Self-contained error handling that keeps the GenServer alive

### 3. Removed Oban Worker Modules

- Deleted `lib/panic/workers/invoker.ex`
- Deleted `lib/panic/workers/archiver.ex`
- Removed entire `lib/panic/workers/` directory

### 4. Updated Application Supervision Tree

In `lib/panic/application.ex`:

- Removed Oban from the supervision tree
- Added Registry for NetworkProcessor GenServers
- Added NetworkSupervisor (DynamicSupervisor)

### 5. Updated LiveViews

#### `PanicWeb.NetworkLive.TerminalComponent`

- Changed from creating an invocation and queuing an Oban job to directly
  calling `NetworkProcessor.start_run/3`
- Simplified the flow - no need to create invocation first
- Added handling for lockout responses

#### `PanicWeb.NetworkLive.Show`

- Changed stop functionality from `Panic.Workers.Invoker.cancel_running_jobs/1`
  to `NetworkProcessor.stop_run/1`

#### `PanicWeb.AdminLive`

- Removed all Oban-related UI elements (job errors table)
- Removed Oban job cancellation functionality
- Simplified the admin interface

### 6. Updated Resources

#### `Panic.Engine.Invocation`

- Removed Oban-related imports and logic from `:start_run` action
- Simplified the action to just return the invocation

#### `Panic.Engine.Network`

- Updated `:stop_run` action to use `NetworkProcessor.stop_run/1` instead of
  Oban job cancellation

### 7. Database Changes

- Created migration to drop Oban tables:
  - `oban_jobs`
  - `oban_peers`
  - `oban_beats`

### 8. Tests

- Created comprehensive tests for NetworkProcessor in
  `test/panic/engine_network_processor_test.exs`
- Removed `test/panic/oban_test.exs`
- Tests cover:
  - GenServer lifecycle
  - Run starting and stopping
  - Lockout period enforcement
  - Error handling
  - Process isolation between tests

## Benefits of the New Approach

1. **Simpler Architecture** - Direct message passing between LiveView and
   GenServer eliminates the job queue layer
2. **Real-time Responsiveness** - No queue delay; invocations start immediately
3. **Natural Domain Mapping** - One GenServer per network maps cleanly to the
   domain model
4. **Less Dependencies** - Removed Oban and ash_oban dependencies
5. **Easier Testing** - GenServers are easier to test in isolation
6. **Better Resource Management** - GenServers are started on-demand and can be
   individually controlled

## Trade-offs

1. **No Persistence** - In-flight invocations are lost if the BEAM crashes (this
   was acceptable per requirements)
2. **No Built-in Retries** - Oban's retry mechanisms are gone (can be
   implemented in GenServer if needed)
3. **No Job Dashboard** - Lost Oban's built-in monitoring dashboard

## Migration Notes

If running this on an existing system:

1. Run migrations to drop Oban tables
2. Any in-flight Oban jobs will be lost
3. The system will start fresh with no running invocations
