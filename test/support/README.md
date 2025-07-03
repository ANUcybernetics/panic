# Test Support Modules

This directory contains shared test helpers and utilities used across the test suite.

## Modules

### `Panic.Generators`
StreamData generators for property-based testing. Provides generators for:
- Users (with and without API tokens)
- Networks (with dummy or real models)
- Invocations
- Models, passwords, emails, etc.

### `Panic.Fixtures`
Simple fixture creation functions that use the generators to create test data.
These are convenience wrappers around the generators for when you need
deterministic test data rather than property-based testing.

### `PanicWeb.Helpers`
Helper functions for Phoenix and LiveView tests:
- User authentication helpers
- NetworkRunner process management
- Database access configuration
- Synchronous test mode setup

### `PanicWeb.Helpers.DatabasePatches`
Convenience macro for setting up database patches in test modules.
Use with `use PanicWeb.Helpers.DatabasePatches` in your test module.

### `Panic.Test.ArchiverPatches`
Test patches for the Archiver module to avoid real file downloads and S3 uploads.
These patches are automatically applied in test_helper.exs.

### `Panic.DataCase`
Standard Phoenix data case for tests that interact with the database.
Sets up the SQL sandbox and provides error helpers.

### `PanicWeb.ConnCase`
Standard Phoenix conn case for controller and LiveView tests.
Sets up test connections and imports necessary test helpers.

## Usage

These modules are automatically compiled when running tests because
`test/support` is added to `elixirc_paths` in `mix.exs` for the test environment.

Example usage in tests:

```elixir
defmodule MyTest do
  use ExUnit.Case, async: false
  
  test "create a user with a network" do
    user = Panic.Fixtures.user()
    network = Panic.Fixtures.network_with_dummy_models(user)
    # ... test logic
  end
end
```