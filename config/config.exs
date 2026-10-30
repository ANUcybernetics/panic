# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# because I'm mostly using integer primary keys - better for sqlite
config :ash, :default_belongs_to_type, :integer

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  redact_sensitive_values_in_errors?: true,
  default_string_length_count: :codepoints,
  many_to_many_destroy_destination_on_match?: true,
  infer_generic_action_reactors?: false

config :ash_json_api,
  show_public_calculations_when_loaded?: false,
  authorize_update_destroy_with_error?: true

config :ash_oban, actor_persister: Panic.Accounts.ActorPersister, pro?: false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.28.2",
  panic: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :mime,
  extensions: %{"json" => "application/vnd.api+json"},
  types: %{"application/vnd.api+json" => ["json"]}

config :panic, Oban,
  engine: Oban.Engines.Lite,
  notifier: Oban.Notifiers.PG,
  queues: [default: 10, invocations: 10, archiver: 2, vestaboards: 1],
  # invocations interrupted by a deploy or Fly autostop retry after this long
  lifeline: [rescue_after: {30, :minutes}],
  shutdown_grace_period: to_timeout(second: 25),
  pruner: [max_age: {1, :day}],
  repo: Panic.Repo,
  cron: [crontab: []]

# SQLite has a single writer. Ash wraps write actions in BEGIN IMMEDIATE
# transactions; :immediate makes direct Repo.transaction/2 calls (Oban's, for
# example) take the write lock up front too, since a deferred transaction that
# upgrades mid-way fails at once regardless of busy_timeout. Keep busy_timeout
# above timeout so a contended write waits for the caller's deadline.
config :panic, Panic.Repo,
  timeout: 15_000,
  busy_timeout: 16_000,
  default_transaction_mode: :immediate

# Configures the endpoint
config :panic, PanicWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PanicWeb.ErrorHTML, json: PanicWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Panic.PubSub,
  live_view: [signing_salt: "aVE1mUTr"]

config :panic, :ash_domains, [Panic.Engine, Panic.Accounts, Panic.Watcher]

config :panic,
  ecto_repos: [Panic.Repo],
  generators: [timestamp_type: :utc_datetime]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :json_api,
        :authentication,
        :tokens,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [:json_api, :resources, :policies, :authorization, :domain, :execution]
    ]
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  panic: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    # Import environment specific config. This must remain at the bottom
    # of this file so it overrides the configuration defined above.
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
