defmodule PanicWeb.Router do
  use PanicWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PanicWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  pipeline :mcp do
    plug :accepts, ["json", "sse"]
  end

  # MCP (Model Context Protocol) servers - must come before catch-all routes
  scope "/ash_ai/mcp" do
    pipe_through :mcp

    forward "/", AshAi.Mcp.Router,
      tools: [],
      protocol_version_statement: "2024-11-05",
      otp_app: :panic
  end

  scope "/", PanicWeb do
    pipe_through :browser

    # Leave out `register_path` and `reset_path` if you don't want to support
    # user registration and/or password resets respectively.
    # sign_in_route(register_path: "/register", reset_path: "/reset")
    sign_in_route(overrides: [PanicWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default])

    sign_out_route AuthController
    auth_routes_for Panic.Accounts.User, to: AuthController
    reset_route []

    # Routes that don't need InvocationWatcher
    ash_authentication_live_session :authentication_required,
      on_mount: [{PanicWeb.LiveUserAuth, :live_user_required}] do
      scope "/users" do
        live "/", UserLive.Index, :index
        live "/new", UserLive.Index, :new
        live "/:user_id", UserLive.Show, :show
        live "/:user_id/update-tokens", UserLive.Show, :update_tokens
        live "/:user_id/new-network", UserLive.Show, :new_network
      end

      scope "/installations" do
        live "/", InstallationLive.Index, :index
        live "/new", InstallationLive.Index, :new
        live "/:id/edit", InstallationLive.Index, :edit

        live "/:id", InstallationLive.Show, :show
        live "/:id/show/edit", InstallationLive.Show, :edit
        live "/:id/show/add_watcher", InstallationLive.Show, :add_watcher
      end

      live "/admin", AdminLive, :index
      
      # API Token management
      scope "/api_tokens" do
        live "/", APITokenLive.Index, :index
        live "/new", APITokenLive.Index, :new
        live "/:id/edit", APITokenLive.Index, :edit

        live "/:id", APITokenLive.Show, :show
        live "/:id/show/edit", APITokenLive.Show, :edit
      end
    end

    # Routes that need InvocationWatcher (authenticated)
    ash_authentication_live_session :authentication_required_with_watcher,
      on_mount: [{PanicWeb.LiveUserAuth, :live_user_required}, {PanicWeb.InvocationWatcher, :auto}] do
      scope "/networks" do
        # no "network list" view, because UserLive.Show fulfils that role
        live "/new", NetworkLive.Index, :new
        live "/:network_id", NetworkLive.Show, :show
        live "/:network_id/edit", NetworkLive.Show, :edit
        live "/:network_id/info/qr", NetworkLive.Info, :qr
        live "/:network_id/info/all", NetworkLive.Info, :all
      end
    end

    # Routes that don't need InvocationWatcher
    ash_authentication_live_session :authentication_optional,
      on_mount: [{PanicWeb.LiveUserAuth, :live_user_optional}] do
      live "/", IndexLive, :index

      # a helper for when you have to type URLs using a TV remote :/
      live "/r/:redirect", RedirectLive, :index
    end

    # Routes that need InvocationWatcher (optional auth)
    ash_authentication_live_session :authentication_optional_with_watcher,
      on_mount: [{PanicWeb.LiveUserAuth, :live_user_optional}, {PanicWeb.InvocationWatcher, :auto}] do
      scope "/networks" do
        live "/:network_id/info", NetworkLive.Info, :info
        live "/:network_id/terminal", NetworkLive.Terminal, :terminal
        live "/:network_id/terminal/expired", NetworkLive.TerminalExpired, :expired
      end

      # static invocation display doesn't need a network ID
      live "/display/static/:invocation_id", NetworkLive.StaticDisplay, :single

      # Installation watcher routes
      live "/i/:id/:watcher_name", InstallationLive.WatcherDisplay, :display
    end

    # "static" pages (still liveviews, though)
    live "/about", AboutLive, :index
  end

  # Other scopes may use custom stacks.

  # scope "/api", PanicWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:panic, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PanicWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Catch-all route for 404 errors
  scope "/", PanicWeb do
    pipe_through :browser
    live "/*path", ErrorLive.NotFound, :not_found
  end
end
