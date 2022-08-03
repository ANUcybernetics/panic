# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# SETUP_TODO - ensure these details are correct
# Option descriptions:
# app_name: This appears in your email layout and also your meta title tag
# business_name: This appears in your landing page footer next to the copyright symbol
# support_email: In your transactional emails there is a "Contact us" email - this is what will appear there
# mailer_default_from_name: The "from" name for your transactional emails
# mailer_default_from_email: The "from" email for your transactional emails
# logo_url_for_emails: The URL to your logo for your transactional emails (needs to be a full URL, not a path)
# seo_description: Will go in your meta description tag
# twitter_url: (deletable) The URL to your Twitter account (used in the landing page footer)
# github_url: (deletable) The URL to your Github account (used in the landing page footer)
# discord_url: (deletable) The URL to your Discord invititation (used in the landing page footer)
config :petal_pro,
  app_name: "Petal",
  business_name: "Petal Pty Ltd",
  support_email: "support@example.com",
  mailer_default_from_name: "Support",
  mailer_default_from_email: "support@example.com",
  logo_url_for_emails:
    "https://res.cloudinary.com/wickedsites/image/upload/v1643336799/petal/petal_logo_light_w5jvlg.png",
  seo_description: "SaaS boilerplate template powered by Elixir's Phoenix and TailwindCSS",
  twitter_url: "https://twitter.com/PetalFramework",
  github_url: "https://github.com/petalframework",
  discord_url: "https://discord.gg/exbwVbjAct"

config :petal_pro,
  ecto_repos: [PetalPro.Repo]

# Configures the endpoint
config :petal_pro, PetalProWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: PetalProWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: PetalPro.PubSub,
  live_view: [signing_salt: "Fd8SWPu3"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :petal_pro, PetalPro.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :petal_components, :error_translator_function, {PetalProWeb.ErrorHelpers, :translate_error}

config :tailwind,
  version: "3.1.2",
  default: [
    args: ~w(
    --config=tailwind.config.js
    --input=css/app.css
    --output=../priv/static/assets/app.css
  ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Oban:
# Queues are specified as a keyword list where the key is the name of the queue and the value is the maximum number of concurrent jobs.
# The following configuration would start four queues with concurrency ranging from 5 to 50: [default: 10, mailers: 20, events: 50, media: 5]
# For now we just have one default queue with up to 5 concurrent jobs (as our database only accepts up to 10 connections so we don't want to overload it)
# Oban provides active pruning of completed, cancelled and discarded jobs - we retain jobs for 24 hours
config :petal_pro, Oban,
  repo: PetalPro.Repo,
  queues: [default: 5],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 3600 * 24},
    {Oban.Plugins.Cron,
     crontab: [
       {"@daily", PetalPro.Workers.ExampleWorker}
       # {"* * * * *", PetalPro.EveryMinuteWorker},
       # {"0 * * * *", PetalPro.EveryHourWorker},
       # {"0 */6 * * *", PetalPro.EverySixHoursWorker},
       # {"0 0 * * SUN", PetalPro.EverySundayWorker},
       # More examples: https://crontab.guru/examples.html
     ]}
  ]

# Specify which languages you support
# To create .po files for a language run `mix gettext.merge priv/gettext --locale fr`
# (fr is France, change to whatever language you want - make sure it's included in the locales config below)
config :petal_pro, PetalProWeb.Gettext, allowed_locales: ~w(en fr)

config :petal_pro, :language_options, [
  %{locale: "en", flag: "🇬🇧", label: "English"},
  %{locale: "fr", flag: "🇫🇷", label: "French"}
]

# Social login providers
# Full list of strategies: https://github.com/ueberauth/ueberauth/wiki/List-of-Strategies
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]},
    github: {Ueberauth.Strategy.Github, [default_scope: "user:email"]}
  ]

config :petal_pro, :passwordless_enabled, true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
