defmodule Panic.MixProject do
  use Mix.Project

  @version "1.4.0"

  def project do
    [
      app: :panic,
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        quality: :test,
        wallaby: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Panic.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  # Type `mix deps.update --all` to update deps (won't updated this file)
  # Type `mix hex.outdated` to see deps that can be updated
  defp deps do
    [
      # Phoenix base
      {:phoenix, "~> 1.6.8"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.9"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.18", override: true},
      {:floki, ">= 0.30.0"},
      {:phoenix_live_dashboard, "~> 0.7"},
      {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.8"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},

      # Emails
      {:phoenix_swoosh, "~> 1.0"},
      {:gen_smtp, "~> 1.2"},
      {:premailex, "~> 0.3.0"},

      # Ecto querying / pagination
      {:query_builder, "~> 1.0"},
      {:flop, "~> 0.17"},

      # Authentication
      {:bcrypt_elixir, "~> 3.0"},
      {:ueberauth, "~> 0.10", override: true},
      {:ueberauth_google, "~> 0.10"},
      {:ueberauth_github, "~> 0.7"},

      # TOTP (2FA)
      {:nimble_totp, "~> 0.2.0"},
      {:eqrcode, "~> 0.1.10"},

      # Hashing
      {:hashids, "~> 2.0"},

      # Assets
      {:tailwind, "~> 0.1.6", runtime: Mix.env() == :dev},

      # Components
      {:petal_components, "~> 0.18"},

      # Utils
      {:email_checker, "~> 0.2.4"},
      {:blankable, "~> 1.0.0"},
      {:currency_formatter, "~> 0.4"},
      {:timex, "~> 3.7", override: true},
      {:inflex, "~> 2.1.0"},
      {:slugify, "~> 1.3"},

      # HTTP client
      {:tesla, "~> 1.4.3"},

      # Testing
      {:wallaby, "~> 0.30", runtime: false, only: :test},
      {:faker, git: "https://github.com/elixirs/faker"},

      # Jobs / Cron
      {:oban, "~> 2.13"},

      # Markdown
      {:earmark, "~> 1.4"},
      {:html_sanitize_ex, "~> 1.4"},

      # Security
      {:content_security_policy, "~> 1.0"},

      # Code quality
      {:sobelow, "~> 0.8", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "tailwind.install", "esbuild.install"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        "esbuild default --minify",
        "tailwind default --minify",
        "phx.digest"
      ],
      # Run to check the quality of your code
      quality: [
        "format --check-formatted",
        "sobelow --config",
        "coveralls",
        "credo"
      ],
      update_translations: ["gettext.extract --merge"],

      # Unlocks unused dependencies (no longer mentioned in the mix.exs file)
      clean_mix_lock: ["deps.unlock --unused"],

      # Only run wallaby (e2e) tests
      wallaby: ["test --only feature"]
    ]
  end
end
