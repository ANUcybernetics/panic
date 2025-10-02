import Config

alias Swoosh.Adapters.Test

config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Do NOT set this value for production
config :bcrypt_elixir, log_rounds: 1

# Print only warnings and errors during test
# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :logger, level: :warning

config :panic, Panic.Mailer, adapter: Test

config :panic, Panic.Repo,
  database: Path.expand("../panic_test.db", __DIR__),
  pool_size: 5,
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  pool: Ecto.Adapters.SQL.Sandbox,
  # because some of the API tests are slow due to cold starts
  ownership_timeout: to_timeout(minute: 10),
  # Increase busy timeout to reduce lock conflicts
  busy_timeout: 5000

config :panic, PanicWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  # In test we don't send emails.
  secret_key_base: "6fMtFbo7K5GsdxuA9hk6X1hEn80aqXOJ37byZ//ba4YknWXTQDDJinMCdbXRj1aR",
  server: false

# Disable vestaboard API calls in tests
config :panic, :disable_vestaboard, true
config :panic, token_signing_secret: "lR3r6rkW8nRkChM35qcKl00FNSK95ra5"

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

config :phoenix_test, :endpoint, PanicWeb.Endpoint

# useful for debugging authorization policy issues

config :swoosh, :api_client, false

# Disable swoosh api client as it is only required for production adapters.
# config :ash, :policies, log_policy_breakdowns: :error
# Configure TowerEmail.Mailer to use Test adapter in tests
config :tower_email, TowerEmail.Mailer, adapter: Test
