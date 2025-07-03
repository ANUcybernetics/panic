# Configure ExUnit to exclude API tests by default
ExUnit.start(exclude: [apikeys: true])

# Setup Repatch for mocking in tests - use shared mode so spawned tasks also get patches
Repatch.setup(enable_global: true, enable_shared: true)

Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

# Apply archiver patches for tests
# Archiving is now skipped in test environment via Mix.env() check in NetworkRunner
# These patches are kept for any remaining direct archiver tests
Panic.Test.ArchiverPatches.apply_patches()