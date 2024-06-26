import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :panic, Panic.Repo,
  database: Path.expand("../panic_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :panic, PanicWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6fMtFbo7K5GsdxuA9hk6X1hEn80aqXOJ37byZ//ba4YknWXTQDDJinMCdbXRj1aR",
  server: false

# In test we don't send emails.
config :panic, Panic.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

config :panic, Oban, testing: :inline

# Do NOT set this value for production
config :bcrypt_elixir, log_rounds: 1
config :panic, :token_signing_secret, "keep_out"

config :panic,
  replicate_req_options: [plug: {Req.Test, Panic.Platforms.Replicate}],
  openai_req_options: [plug: {Req.Test, Panic.Platforms.OpenAI}],
  vestaboard_req_options: [plug: {Req.Test, Panic.Platforms.Vestaboard}]
