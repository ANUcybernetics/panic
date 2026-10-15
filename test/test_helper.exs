# Configure ExUnit to exclude API tests by default
ExUnit.start(exclude: [apikeys: true, external_deps: true])

# Setup Repatch for mocking in tests - use shared mode so spawned tasks also get patches
Repatch.setup(enable_global: true, enable_shared: true)

Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

# Archiver patches avoid real downloads and S3 uploads when archive jobs run
Panic.Test.ArchiverPatches.apply_patches()

# Apply all external API patches globally to prevent real API calls in tests
Panic.ExternalAPIPatches.setup()
