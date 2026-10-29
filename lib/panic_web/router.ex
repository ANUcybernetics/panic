defmodule PanicWeb.Router do
  use PanicWeb, :router
  use AshAuthentication.Phoenix.Router

  import PanicWeb.ApiAuth, only: [reject_blank_bearer: 2, require_admin: 2]

  alias Panic.Accounts.User

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
    plug :reject_blank_bearer

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: User,
      required?: false,
      on_error: &PanicWeb.ApiAuth.unauthorized/2

    plug :require_admin
  end

  scope "/api" do
    forward "/swaggerui", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/open_api",
      default_model_expand_depth: 4
  end

  scope "/api" do
    pipe_through :api

    forward "/", PanicWeb.AshJsonApiRouter
  end

  scope "/", PanicWeb do
    pipe_through :browser

    sign_in_route(
      overrides: [PanicWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default],
      auth_routes_prefix: "/auth"
    )

    sign_out_route AuthController
    auth_routes AuthController, User

    # Routes that don't need WatcherSubscriber
    ash_authentication_live_session :authentication_required,
      on_mount: [{PanicWeb.LiveUserAuth, :live_user_required}] do
      scope "/users" do
        live "/", UserLive.Index, :index
        live "/:user_id", UserLive.Show, :show
        live "/:user_id/new-network", UserLive.Show, :new_network
      end

      scope "/installations" do
        live "/", InstallationLive.Index, :index
        live "/new", InstallationLive.Index, :new
        live "/:id/edit", InstallationLive.Index, :edit

        live "/:id", InstallationLive.Show, :show
        live "/:id/show/edit", InstallationLive.Show, :edit
        live "/:id/show/add_watcher", InstallationLive.Show, :add_watcher
        live "/:id/show/edit_watcher/:name", InstallationLive.Show, :edit_watcher
      end
    end

    ash_authentication_live_session :admin_required,
      on_mount: [{PanicWeb.LiveUserAuth, :live_admin_required}] do
      live "/admin", AdminLive, :index
    end

    # Database backup endpoint (checks for an admin itself)
    get "/admin/backup", BackupController, :download

    # Routes that need WatcherSubscriber (authenticated)
    ash_authentication_live_session :authentication_required_with_watcher,
      on_mount: [
        {PanicWeb.LiveUserAuth, :live_user_required},
        {PanicWeb.WatcherSubscriber, :auto}
      ] do
      scope "/networks" do
        # no "network list" view, because UserLive.Show fulfils that role
        live "/new", NetworkLive.Index, :new
        live "/:network_id", NetworkLive.Show, :show
        live "/:network_id/edit", NetworkLive.Show, :edit
        live "/:network_id/info/qr", NetworkLive.Info, :qr
        live "/:network_id/info/all", NetworkLive.Info, :all
      end
    end

    # Routes that don't need WatcherSubscriber
    ash_authentication_live_session :authentication_optional,
      on_mount: [{PanicWeb.LiveUserAuth, :live_user_optional}] do
      live "/", IndexLive, :index

      # a helper for when you have to type URLs using a TV remote :/
      live "/r/:redirect", RedirectLive, :index
    end

    # Routes that need WatcherSubscriber (optional auth)
    ash_authentication_live_session :authentication_optional_with_watcher,
      on_mount: [
        {PanicWeb.LiveUserAuth, :live_user_optional},
        {PanicWeb.WatcherSubscriber, :auto}
      ] do
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

  # Enable LiveDashboard in development
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
    end
  end

  # Catch-all route for 404 errors
  scope "/", PanicWeb do
    pipe_through :browser
    live "/*path", ErrorLive.NotFound, :not_found
  end
end
