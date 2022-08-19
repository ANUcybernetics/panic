defmodule PanicWeb.Router do
  use PanicWeb, :router

  alias PanicWeb.Router.Helpers, as: Routes
  import PanicWeb.UserAuth
  import PanicWeb.OrgPlugs
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PanicWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug PetalFramework.SetLocalePlug, gettext: PanicWeb.Gettext
  end

  pipeline :protected do
    plug :require_authenticated_user
    plug :kick_user_if_suspended_or_deleted
    plug :onboard_new_users
    plug :assign_org_data
  end

  # Public routes. Though `@current_user` will be available if logged in
  scope "/", PanicWeb do
    pipe_through [:browser, :onboard_new_users]

    get "/", PageController, :landing_page
    get "/privacy", PageController, :privacy
    get "/license", PageController, :license

    # Note: The page_builder references like the one below are to help you when building new page pages.
    # To build a page, simply type in the browser URL bar a route you haven't created yet - eg "/contact-us", and fill out the form.
    # You can add/remove page_builder references in the router and they'll show up in the page builder - use the format page_builder:[static|live]:<custom name>

    # page_builder:static:public

    live_session :public,
      on_mount: [
        {PanicWeb.UserOnMountHooks, :maybe_assign_user}
      ] do
      # page_builder:live:public
    end
  end

  # Public routes, but not redirected when a user is logged in but hasn't onboarded
  scope "/", PanicWeb do
    pipe_through [:browser]

    delete "/users/sign-out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update

    # Mailbluster must be setup to send users here (see mail_bluster.ex)
    get "/unsubscribe/mailbluster/:email",
        UserSettingsController,
        :unsubscribe_from_mailbluster

    # Mailbluster unsubscribers will end up here
    get "/unsubscribe/marketing",
        UserSettingsController,
        :mailbluster_unsubscribed_confirmation

    get "/unsubscribe/:code/:notification_subscription",
        UserSettingsController,
        :unsubscribe_from_notification_subscription

    put "/unsubscribe/:code/:notification_subscription",
        UserSettingsController,
        :toggle_notification_subscription
  end

  # Auth related routes - signed in users will get redirected away. Used for register, sign in, etc
  scope "/", PanicWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]
    get "/register", UserRegistrationController, :new
    post "/register", UserRegistrationController, :create
    get "/sign-in", UserSessionController, :new
    post "/sign-in", UserSessionController, :create

    # Ueberauth external provider sign ins
    get "/auth/:provider", UserUeberauthController, :request
    get "/auth/:provider/callback", UserUeberauthController, :callback

    # Reset password
    get "/users/reset-password", UserResetPasswordController, :new
    post "/users/reset-password", UserResetPasswordController, :create
    get "/users/reset-password/:token", UserResetPasswordController, :edit
    put "/users/reset-password/:token", UserResetPasswordController, :update

    # Passwordless sign in
    scope "/sign-in/passwordless" do
      pipe_through [:redirect_if_passwordless_disabled]

      post "/", UserSessionController, :create_from_token
      live "/", PasswordlessAuthLive, :sign_in
      live "/enter-pin/:hashed_user_id", PasswordlessAuthLive, :sign_in_code
    end
  end

  # Don't force onboarding for onboarding (redirect loop)
  scope "/", PanicWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :kick_user_if_suspended_or_deleted
    ]

    live_session :require_authenticated_user_for_onboarding,
      on_mount: [
        {PanicWeb.UserOnMountHooks, :require_authenticated_user}
      ] do
      live "/users/onboarding", UserOnboardingLive
    end
  end

  # Protected: for signed in but not necessarily confirmed users
  scope "/", PanicWeb do
    pipe_through [:browser, :protected]

    # Update password will log a user out and back in, hence can't be in a live view.
    put "/users/settings/update-password", UserSettingsController, :update_password

    # When a user changes their email they'll be sent a link - that link goes to here (which instantly redirects them to their profile page)
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email

    # 2fa routes
    get "/users/totp", UserTOTPController, :new
    post "/users/totp", UserTOTPController, :create

    # page_builder:static:protected_but_maybe_unconfirmed

    live_session :require_authenticated_user,
      on_mount: [
        {PanicWeb.UserOnMountHooks, :require_authenticated_user},
        {PanicWeb.OrgOnMountHooks, :assign_org_data}
      ] do
      live "/users/edit-profile", EditProfileLive
      live "/users/edit-email", EditEmailLive
      live "/users/change-password", EditPasswordLive
      live "/users/edit-notifications", EditNotificationsLive
      live "/users/org-invitations", UserOrgInvitationsLive
      live "/users/two-factor-authentication", EditTotpLive
      live "/app", DashboardLive

      live "/orgs", OrgsLive, :index
      # page_builder:live:protected_but_maybe_unconfirmed
    end
  end

  # Protected: for confirmed users only. Most of your routes should go here.
  scope "/", PanicWeb do
    pipe_through [:browser, :protected, :require_confirmed_user]

    # page_builder:static:protected

    live_session :require_confirmed_user,
      on_mount: [
        {PanicWeb.UserOnMountHooks, :require_confirmed_user},
        {PanicWeb.OrgOnMountHooks, :assign_org_data}
      ] do
      live "/orgs/new", OrgsLive, :new
      # page_builder:live:protected

      live "/networks", NetworkLive.Index, :index
      live "/networks/new", NetworkLive.Index, :new

      live "/networks/:id", NetworkLive.Show, :show
      live "/networks/:id/edit", NetworkLive.Edit, :edit
      live "/networks/:id/archive", NetworkLive.Archive, :show
    end

    # For org members only
    scope "/org/:org_slug" do
      pipe_through [:require_org_member]

      # All pages for members of an org
      live_session :require_org_member,
        on_mount: [
          {PanicWeb.UserOnMountHooks, :require_confirmed_user},
          {PanicWeb.OrgOnMountHooks, :assign_org_data},
          {PanicWeb.OrgOnMountHooks, :require_org_member}
        ] do
        live "/", OrgDashboardLive
      end

      # All pages for org admins only
      scope "/" do
        pipe_through [:require_org_admin]

        live_session :require_org_admin,
          on_mount: [
            {PanicWeb.UserOnMountHooks, :require_confirmed_user},
            {PanicWeb.OrgOnMountHooks, :assign_org_data},
            {PanicWeb.OrgOnMountHooks, :require_org_admin}
          ] do
          live "/edit", EditOrgLive
          live "/team", OrgTeamLive, :index
          live "/team/invite", OrgTeamLive, :invite
          live "/team/memberships/:id/edit", OrgTeamLive, :edit_membership
        end
      end
    end
  end

  # Admin only routes - used for all things admin related
  scope "/admin", PanicWeb do
    pipe_through [
      :browser,
      :protected,
      :require_admin_user
    ]

    live_dashboard "/server", metrics: PanicWeb.Telemetry

    live_session :require_admin_user,
      on_mount: [
        {PanicWeb.UserOnMountHooks, :require_admin_user}
      ] do
      live "/users", AdminUsersLive, :index
      live "/users/:user_id", AdminUsersLive, :edit
      live "/logs", LogsLive, :index
      # page_builder:live:admin
    end
  end

  # Development only routes (don't use route helpers to generate paths for these routes or they'll fail in production)
  # eg. instead of `Routes.live_path(@conn_or_socket, DevDashboardLive)`, just write `/dev`
  if Mix.env() in [:dev, :test] do
    scope "/dev" do
      pipe_through :browser

      # View sent emails
      forward "/mailbox", Plug.Swoosh.MailboxPreview

      # Show a list of all your apps emails - use this when designing your transactional emails
      scope "/emails" do
        pipe_through([:require_authenticated_user])

        get "/", PanicWeb.EmailTestingController, :index
        get "/sent", PanicWeb.EmailTestingController, :sent
        get "/preview/:email_name", PanicWeb.EmailTestingController, :preview
        post "/send_test_email/:email_name", PanicWeb.EmailTestingController, :send_test_email
        get "/show/:email_name", PanicWeb.EmailTestingController, :show_html
      end
    end

    scope "/", PanicWeb do
      pipe_through :browser

      live_session :dev, on_mount: [{PanicWeb.UserOnMountHooks, :maybe_assign_user}] do
        live "/dev", DevDashboardLive
        live "/:path_root", PageBuilderLive
        live "/:path_root/:path_child", PageBuilderLive
      end
    end
  end

  # This plug shows an onboarding screen for new users. Good for either collecting more details or showing a welcome screen.
  # To remove: search for "onboard_new_users" and remove it from the pipe_through list
  defp onboard_new_users(conn, _opts) do
    if conn.assigns[:current_user] && !conn.assigns.current_user.is_onboarded do
      conn
      |> redirect(
        to:
          Routes.live_path(conn, PanicWeb.UserOnboardingLive, user_return_to: current_path(conn))
      )
      |> halt()
    else
      conn
    end
  end

  def redirect_if_passwordless_disabled(conn, _opts) do
    if Panic.config(:passwordless_enabled) do
      conn
    else
      conn
      |> redirect(to: Routes.user_session_path(conn, :new))
      |> halt()
    end
  end
end
