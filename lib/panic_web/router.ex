defmodule PanicWeb.Router do
  use PanicWeb, :router

  import PanicWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PanicWeb.Layouts, :root}
    plug :protect_from_forgery

    plug(:put_secure_browser_headers, %{
      "content-security-policy" =>
        ContentSecurityPolicy.serialize(
          struct(
            ContentSecurityPolicy.Policy,
            Application.compile_env(:panic, :content_security_policy)
          )
        )
    })

    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
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

  ## Account management routes

  scope "/", PanicWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{PanicWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  ## public network routes

  scope "/", PanicWeb do
    pipe_through [:browser]

    live_session :public_network_routes,
      on_mount: [{PanicWeb.UserAuth, :mount_current_user}] do
      live "/", HomeLive.Index, :index

      ## "running grid" view
      live "/networks/:id", NetworkLive.Show, :show

      # should be an option for networks to be given a (public) permalink
      live "/networks/permalink", NetworkLive.Index, :latest
      ## also accepts query params for screen/grid_mod and will live update as
      ## new predictions come in
      live "/networks/:network_id/predictions/:id", PredictionLive.Show, :show
    end
  end

  ## authenticated network routes

  scope "/", PanicWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated_network_routes,
      on_mount: [{PanicWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      live "/networks", NetworkLive.Index, :index
      live "/networks/new", NetworkLive.Index, :new
      live "/networks/:id/edit", NetworkLive.Index, :edit
      ## the "all in one" terminal plus running grid view
      live "/networks/:id/show/edit", NetworkLive.Show, :edit

      live "/networks/:id/qrcode", NetworkLive.Show, :qrcode

      live "/networks/:network_id/predictions", PredictionLive.Index, :index
      # the "terminal"
      live "/networks/:network_id/predictions/new", PredictionLive.Index, :new

      live "/api_tokens", APITokenLive.Index, :index
      live "/api_tokens/new", APITokenLive.Index, :new
      live "/api_tokens/:id/edit", APITokenLive.Index, :edit

      live "/api_tokens/:id", APITokenLive.Show, :show
      live "/api_tokens/:id/show/edit", APITokenLive.Show, :edit
    end
  end

  scope "/", PanicWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{PanicWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
