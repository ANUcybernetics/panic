defmodule PanicWeb.AuthRoutes do
  defmacro __using__(_) do
    quote do
      scope "/auth", PanicWeb do
        pipe_through [:browser]

        delete "/sign-out", UserSessionController, :delete
        post "/resend_confirm_email", UserConfirmationController, :resend_confirm_email
        get "/confirm/:token", UserConfirmationController, :edit
        post "/confirm/:token", UserConfirmationController, :update
        get "/unconfirmed", UserConfirmationController, :unconfirmed
        get "/reset-password", UserResetPasswordController, :new
        post "/reset-password", UserResetPasswordController, :create
        get "/reset-password/:token", UserResetPasswordController, :edit
        put "/reset-password/:token", UserResetPasswordController, :update
      end

      scope "/auth", PanicWeb do
        pipe_through [:browser, :redirect_if_user_is_authenticated]
        get "/register", UserRegistrationController, :new
        post "/register", UserRegistrationController, :create
        get "/sign-in", UserSessionController, :new
        post "/sign-in", UserSessionController, :create
        get "/:provider", UserUeberauthController, :request
        get "/:provider/callback", UserUeberauthController, :callback

        scope "/sign-in/passwordless" do
          post "/", UserSessionController, :create_from_token
          live "/", PasswordlessAuthLive, :sign_in
          live "/enter-pin/:hashed_user_id", PasswordlessAuthLive, :sign_in_code
        end
      end
    end
  end
end
