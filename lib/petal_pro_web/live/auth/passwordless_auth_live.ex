defmodule PetalProWeb.PasswordlessAuthLive do
  @moduledoc """
  This module is used to handle the passwordless auth flow.
  A user enters their email and submits. If no user exists for the user, then one is created with a random password.
  A user will fill in their name at the onboarding screen.

  Process:
  1: User submits email.
  2: Find or create a user, set it as assigns.auth_user
  3: Push patch to /passwordless/sign-in-code/:hashed_user_id
  4: User enters code that was sent to their email.
  5: A form is submited that POSTs a token to UserSessionController.create_from_token/2
  6: User is logged in
  """
  use PetalProWeb, :live_view
  require Logger
  alias PetalPro.Accounts
  alias PetalPro.Accounts.{User, UserNotifier, UserToken}

  @allowed_attempts 3
  @hash_salt "passwordless"

  def mount(params, _session, socket) do
    socket =
      assign(socket,
        changeset: Accounts.change_user_passwordless_registration(%User{}, %{}),
        user_return_to: Map.get(params, "user_return_to", nil),
        error_message: nil,
        auth_user: nil,
        enable_resend?: nil,
        attempts: 0,
        sign_in_token: nil,
        token_changeset: build_token_changeset(%{}),
        trigger_submit: false
      )

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :sign_in, _params), do: assign(socket, error_message: nil)

  defp apply_action(socket, :sign_in_code, %{"hashed_user_id" => hashed_user_id}) do
    user_id = decode_user_id(hashed_user_id)

    if socket.assigns.auth_user do
      socket
    else
      # Re-assign page variables if this is remounted (eg. socket disconnected)
      # This can happen on mobile devices when user switches to mail app to copy/paste pin
      auth_user = Accounts.get_user!(user_id)

      if UserToken.valid_pin_exists?(auth_user) do
        assign(socket, auth_user: auth_user)
      else
        socket
        |> push_patch(to: Routes.passwordless_auth_path(socket, :sign_in))
      end
    end
  end

  def handle_event("submit_email", %{"user" => %{"email" => email}}, socket) do
    send_pin(socket, email)
  end

  # When pin is less than 6 digits, ignore it
  def handle_event("validate_pin", %{"auth" => %{"pin" => pin}}, socket)
      when byte_size(pin) < 6 do
    {:noreply, assign(socket, error_message: nil)}
  end

  # Handle nil user
  def handle_event("validate_pin", %{"auth" => %{"pin" => _pin}}, socket)
      when socket.assigns.auth_user == nil do
    {:noreply, push_patch(socket, to: Routes.passwordless_auth_path(socket, :sign_in))}
  end

  def handle_event("validate_pin", %{"auth" => %{"pin" => submitted_pin}}, socket)
      when byte_size(submitted_pin) >= 6 do
    submitted_pin = String.trim(submitted_pin)

    case UserToken.check_pin(socket.assigns.auth_user, submitted_pin) do
      nil ->
        if socket.assigns.attempts >= @allowed_attempts do
          # Delete the user_token holding the pin
          UserToken.clear_pins(socket.assigns.auth_user)

          PetalPro.Logs.log_async("passwordless_pin_too_many_incorrect_attempts", %{
            user: socket.assigns.auth_user
          })

          socket =
            push_patch(socket, to: Routes.passwordless_auth_path(socket, :sign_in))
            |> put_flash(:error, gettext("Too many incorrect attempts."))

          {:noreply, socket}
        else
          {:noreply,
           assign(socket, %{
             error_message: gettext("Not a valid pin. Sure you typed it correctly?"),
             attempts: socket.assigns.attempts + 1,
             enable_resend?: true
           })}
        end

      _user_token ->
        sign_in_token =
          socket.assigns.auth_user
          |> Accounts.generate_user_session_token()
          |> Base.encode64()

        token_changeset =
          build_token_changeset(%{
            sign_in_token: sign_in_token,
            user_return_to: socket.assigns.user_return_to
          })

        {:noreply, assign(socket, token_changeset: token_changeset, trigger_submit: true)}
    end
  end

  # Fallback function if the pin wasn't yet 6 digits.
  def handle_event("validate_pin", _, socket),
    do: {:noreply, socket}

  def handle_event("resend", _, socket) do
    user = socket.assigns[:auth_user]

    if user do
      {pin, _user_token} = UserToken.create_pin_token(user)
      UserNotifier.deliver_passwordless_pin(user, pin)
      Accounts.user_lifecycle_action("after_passwordless_pin_sent", user, %{pin: pin})

      {:noreply,
       assign(socket, %{
         enable_resend?: false,
         error_message: nil
       })}
    else
      {:noreply, socket}
    end
  end

  defp send_pin(socket, email) do
    email = Util.trim(email)

    with {:ok, user} <- Accounts.get_or_create_user(%{email: email}, "passwordless"),
         {pin, _user_token} <- UserToken.create_pin_token(user) do
      UserNotifier.deliver_passwordless_pin(user, pin)
      Accounts.user_lifecycle_action("after_passwordless_pin_sent", user, %{pin: pin})

      {:noreply,
       assign(socket, %{
         email: email,
         error_message: nil,
         auth_user: user,
         attempts: 0
       })
       |> push_patch(
         to:
           Routes.passwordless_auth_path(
             socket,
             :sign_in_code,
             encode_user_id(user.id)
           )
       )}
    else
      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}

      _ ->
        {:noreply, assign(socket, error_message: gettext("Unknown error."))}
    end
  end

  defp decode_user_id(hashed_user_id),
    do: HashId.decode(hashed_user_id, salt_addition: @hash_salt)

  defp encode_user_id(user_id), do: HashId.encode(user_id, salt_addition: @hash_salt)

  defp build_token_changeset(params) do
    types = %{
      pin: :number,
      sign_in_token: :string,
      user_return_to: :string
    }

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
  end
end
