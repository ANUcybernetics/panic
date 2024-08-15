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

  scope "/", PanicWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Leave out `register_path` and `reset_path` if you don't want to support
    # user registration and/or password resets respectively.
    # sign_in_route(register_path: "/register", reset_path: "/reset")
    sign_in_route()
    sign_out_route AuthController
    auth_routes_for Panic.Accounts.User, to: AuthController
    reset_route []

    ash_authentication_live_session :authentication_required,
      on_mount: {PanicWeb.LiveUserAuth, :live_user_required} do
      scope "/users" do
        live "/", UserLive.Index, :index
        live "/new", UserLive.Index, :new
        live "/:user_id", UserLive.Show, :show
        live "/:user_id/show/edit", UserLive.Show, :edit
      end

      scope "/networks" do
        live "/", NetworkLive.Index, :index
        live "/new", NetworkLive.Index, :new
        live "/:network_id", NetworkLive.Show, :show
        live "/:network_id/show/edit", NetworkLive.Show, :edit
        live "/:network_id/invocations/:invocation_id", InvocationLive.Show, :show
        live "/:network_id/invocations/live/:type/a/b", InvocationLive.Show, :live
      end
    end

    ash_authentication_live_session :authentication_optional,
      on_mount: {PanicWeb.LiveUserAuth, :live_user_optional} do
      live "/", PanicWebLive.Index, :index
    end
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
end
