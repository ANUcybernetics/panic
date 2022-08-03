defmodule PetalPro.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias PetalPro.Repo
  require Logger

  alias PetalPro.Accounts.{User, UserToken, UserNotifier, UserTOTP}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Attempts to get gets a user by email. If the user is not found, create a new user.

  ## Examples

      iex> get_or_create_user(%{email: "new@example.com", name: "New User"})
      {:ok, %User{}}

  """
  def get_or_create_user(attrs, registration_type) do
    case get_user_by_email(attrs.email) do
      %User{} = user ->
        {:ok, user}

      _ ->
        user_registration_changeset(registration_type, attrs)
        |> Repo.insert()
    end
  end

  defp user_registration_changeset("external_provider", attrs),
    do: User.external_provider_changeset(%User{}, attrs)

  defp user_registration_changeset("passwordless", attrs),
    do: User.passwordless_registration_changeset(%User{}, attrs)

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user registration without a password.
  """
  def change_user_passwordless_registration(%User{} = user, attrs \\ %{}) do
    User.passwordless_registration_changeset(user, attrs)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Emulates that the e-mail will change without actually changing
  it in the database. Used for email changes and no passwords.

  ## Examples

      iex> check_if_can_change_user_email(user, %{email: "valid_email@gmail.com"})
      {:ok, %User{}}

      iex> check_if_can_change_user_email(user, %{email: "existing_users_email@gmail.com"})
      {:error, %Ecto.Changeset{}}

  """
  def check_if_can_change_user_email(user, attrs \\ %{}) do
    User.new_email_changeset(user, attrs)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset = user |> User.email_changeset(%{email: email}) |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &Routes.user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user as a admin.

  ## Examples

      iex> change_user_as_admin(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_as_admin(user, attrs \\ %{}) do
    User.admin_changeset(user, attrs)
  end

  def change_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def update_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def update_user_as_admin(user, attrs) do
    user
    |> User.admin_changeset(attrs)
    |> Repo.update()
  end

  def update_last_signed_in_info(user, ip) do
    user
    |> User.last_signed_in_changeset(ip)
    |> Repo.update()
  end

  def suspend_user(user) do
    user
    |> User.admin_changeset(%{is_suspended: true})
    |> Repo.update()
  end

  def undo_suspend_user(user) do
    user
    |> User.admin_changeset(%{is_suspended: false})
    |> Repo.update()
  end

  def delete_user(user) do
    user
    |> User.admin_changeset(%{is_deleted: true})
    |> Repo.update()
  end

  def undo_delete_user(user) do
    user
    |> User.admin_changeset(%{is_deleted: false})
    |> Repo.update()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(nil), do: nil

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      url = confirmation_url_fun.(encoded_token)

      if PetalPro.config(:env) == :dev do
        Logger.info("--- Confirmation URL: #{url}")
      end

      UserNotifier.deliver_confirmation_instructions(user, url)
    end
  end

  @doc """
  Confirms a user without checking any tokens
  """

  def confirm_user!(%User{confirmed_at: nil} = user) do
    with {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      user
    end
  end

  def confirm_user!(user), do: user

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &Routes.user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def toggle_admin(user) do
    user
    |> User.change_admin_changeset()
    |> Repo.update()
  end

  def preload_org_data(user, current_org_slug \\ nil) do
    user = Repo.preload(user, :orgs)

    if current_org_slug do
      %{user | current_org: Enum.find(user.orgs, &(&1.slug == current_org_slug))}
    else
      user
    end
  end

  @doc """
  Returns a User changeset that is valid if the current password is valid.

  It returns a changeset. The changeset has an action if the current password
  is not nil.
  """
  def validate_user_current_password(user, current_password) do
    user
    |> Ecto.Changeset.change()
    |> User.validate_current_password(current_password)
    |> attach_action_if_current_password(current_password)
  end

  defp attach_action_if_current_password(changeset, nil),
    do: changeset

  defp attach_action_if_current_password(changeset, _),
    do: Map.replace!(changeset, :action, :validate)

  ## 2FA / TOTP (Time based One Time Password)

  def two_factor_auth_enabled?(user) do
    !!get_user_totp(user)
  end

  @doc """
  Gets the %UserTOTP{} entry, if any.
  """
  def get_user_totp(user) do
    Repo.get_by(UserTOTP, user_id: user.id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing user TOTP.

  ## Examples

      iex> change_user_totp(%UserTOTP{})
      %Ecto.Changeset{data: %UserTOTP{}}

  """
  def change_user_totp(totp, attrs \\ %{}) do
    UserTOTP.changeset(totp, attrs)
  end

  @doc """
  Updates the TOTP secret.

  The secret is a random 20 bytes binary that is used to generate the QR Code to
  enable 2FA using auth applications. It will only be updated if the OTP code
  sent is valid.

  ## Examples

      iex> upsert_user_totp(%UserTOTP{secret: <<...>>}, code: "123456")
      {:ok, %Ecto.Changeset{data: %UserTOTP{}}}

  """
  def upsert_user_totp(totp, attrs) do
    totp_changeset =
      totp
      |> UserTOTP.changeset(attrs)
      |> UserTOTP.ensure_backup_codes()
      # If we are updating, let's make sure the secret
      # in the struct propagates to the changeset.
      |> Ecto.Changeset.force_change(:secret, totp.secret)

    Repo.insert_or_update(totp_changeset)
  end

  @doc """
  Regenerates the user backup codes for totp.

  ## Examples

      iex> regenerate_user_totp_backup_codes(%UserTOTP{})
      %UserTOTP{backup_codes: [...]}

  """
  def regenerate_user_totp_backup_codes(totp) do
    totp
    |> Ecto.Changeset.change()
    |> UserTOTP.regenerate_backup_codes()
    |> Repo.update!()
  end

  @doc """
  Disables the TOTP configuration for the given user.
  """
  def delete_user_totp(user_totp) do
    Repo.delete!(user_totp)
  end

  @doc """
  Validates if the given TOTP code is valid.
  """
  def validate_user_totp(user, code) do
    totp = Repo.get_by!(UserTOTP, user_id: user.id)

    cond do
      UserTOTP.valid_totp?(totp, code) ->
        :valid_totp

      changeset = UserTOTP.validate_backup_code(totp, code) ->
        totp = Repo.update!(changeset)
        {:valid_backup_code, Enum.count(totp.backup_codes, &is_nil(&1.used_at))}

      true ->
        :invalid
    end
  end

  # User lifecyle actions - these allow you to hook into certain user events and do secondary tasks like create logs, send Slack messages etc.
  def user_lifecycle_action(action, user, opts \\ %{})

  def user_lifecycle_action("after_register", user, _) do
    PetalPro.Logs.log_async("register", %{user: user})
    PetalPro.Orgs.sync_user_invitations(user)

    PetalPro.Slack.message("""
    :bust_in_silhouette: *A new user joined!*
    *Name*: #{user.name}

    #{PetalProWeb.Router.Helpers.admin_users_url(PetalProWeb.Endpoint, :edit, user)}
    """)
  end

  def user_lifecycle_action("after_confirm_email", user, _) do
    PetalPro.Logs.log_async("confirm_email", %{user: user})
    PetalPro.Orgs.sync_user_invitations(user)
  end

  def user_lifecycle_action("after_sign_in", user, %{ip: ip}) do
    PetalPro.Logs.log_async("sign_in", %{user: user})
    {:ok, user} = update_last_signed_in_info(user, ip)
    PetalPro.MailBluster.sync_user_async(user)
  end

  def user_lifecycle_action("after_update_profile", user, _) do
    PetalPro.Logs.log_async("update_profile", %{user: user})
    PetalPro.MailBluster.sync_user_async(user)
  end

  def user_lifecycle_action("after_confirm_new_email", user, _) do
    PetalPro.Logs.log_async("confirm_new_email", %{user: user})
    PetalPro.Orgs.sync_user_invitations(user)
  end

  def user_lifecycle_action("request_new_email", user, %{new_email: new_email}) do
    PetalPro.Logs.log_async("request_new_email", %{user: user, metadata: %{new_email: new_email}})
  end

  def user_lifecycle_action("after_passwordless_pin_sent", user, %{pin: pin}) do
    PetalPro.Logs.log("passwordless_pin_sent", %{user: user})

    # Allow devs to see the pin in the server logs to sign in with
    if PetalPro.config(:env) == :dev do
      Logger.info("----------- PIN ------------")
      Logger.info(pin)
    end
  end
end
