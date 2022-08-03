defmodule PanicWeb.UserUeberauthController do
  @moduledoc """
  Write ueberauth callbacks here. A callback is called after a user has successfully authenticated with a provider (eg. Google or Github).
  """
  use PanicWeb, :controller

  alias Panic.Accounts
  alias PanicWeb.UserAuth

  plug Ueberauth

  # Google - https://github.com/ueberauth/ueberauth_google
  def callback(%{assigns: %{ueberauth_auth: %{info: user_info}}} = conn, %{"provider" => "google"}) do
    user_params = %{
      email: user_info.email,
      name: combine_first_and_last_name(user_info),
      avatar: user_info.image
    }

    case Accounts.get_or_create_user(user_params, "external_provider") do
      {:ok, user} ->
        user = Accounts.confirm_user!(user)
        UserAuth.log_in_user(conn, user)

      {:error, _} ->
        conn
        |> put_flash(:error, "Authentication failed")
        |> redirect(to: "/")
    end
  end

  # Github - https://github.com/ueberauth/ueberauth_github
  def callback(%{assigns: %{ueberauth_auth: %{info: user_info}}} = conn, %{"provider" => "github"}) do
    user_params = %{
      email: user_info.email,
      name: user_info.name || user_info.nickname,
      avatar: user_info.image
    }

    case Accounts.get_or_create_user(user_params, "external_provider") do
      {:ok, user} ->
        user = Accounts.confirm_user!(user)
        UserAuth.log_in_user(conn, user)

      {:error, _} ->
        conn
        |> put_flash(:error, "Authentication failed")
        |> redirect(to: "/")
    end
  end

  # If no other callbacks match then we assume authentication failed.
  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed")
    |> redirect(to: "/")
  end

  # There could be a chance that last name isn't available.
  defp combine_first_and_last_name(user_info) do
    [user_info.first_name, user_info.last_name]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end
end
