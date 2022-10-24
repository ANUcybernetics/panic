defmodule PanicWeb.UserRegistrationController do
  use PanicWeb, :controller

  alias Panic.Accounts
  alias Panic.Accounts.User
  alias PanicWeb.UserAuth

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset, page_title: gettext("Register"))
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(conn, :edit, &1)
          )

        Accounts.user_lifecycle_action("after_register", user)

        conn
        |> put_flash(:info, gettext("User created successfully."))
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
