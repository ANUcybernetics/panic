defmodule PetalProWeb.Helpers do
  @moduledoc """
  A set of helpers used in web related views and templates. These functions can be called anywhere in a heex template.
  """
  def main_menu_items(current_user) do
    PetalProWeb.Menus.main_menu_items(current_user)
  end

  def user_menu_items(current_user) do
    PetalProWeb.Menus.user_menu_items(current_user)
  end

  def public_menu_items(current_user) do
    PetalProWeb.Menus.public_menu_items(current_user)
  end

  def get_menu_item(name, current_user) do
    PetalProWeb.Menus.get_link(name, current_user)
  end

  def home_path(nil), do: "/"
  def home_path(current_user), do: PetalProWeb.Menus.get_link(:dashboard, current_user).path

  # Always use this when rendering a user's name
  # This way, if you want to change to something like "user.first_name user.last_name", you only have to change one place
  def user_name(nil), do: nil
  def user_name(user), do: user.name

  def user_avatar_url(nil), do: nil
  def user_avatar_url(user), do: user.avatar

  def is_admin?(%{is_admin: true}), do: true
  def is_admin?(_), do: false

  def format_date(date, format \\ "{ISOdate}"), do: Timex.format!(date, format)

  # Autofocuses the input
  # <input {alpine_autofocus()} />
  def alpine_autofocus() do
    %{
      "x-data": "",
      "x-init": "$nextTick(() => { $el.focus() });"
    }
  end

  @doc """
  When you want to display code in a heex template, you can use this helper to escape it.
  """
  def code_block(code) do
    Phoenix.HTML.raw("""
    <pre>#{code}</pre>
    """)
  end

  @doc """
  Checks if a ueberauth provider has been enabled with the correct environment variables

  ## Examples

      iex> auth_provider_loaded?("google")
      iex> true
  """
  def auth_provider_loaded?(provider) do
    case provider do
      "google" ->
        !!get_in(Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth), [:client_id])

      "github" ->
        !!get_in(Application.get_env(:ueberauth, Ueberauth.Strategy.Github.OAuth), [:client_id])

      "passwordless" ->
        !!PetalPro.config(:passwordless_enabled)
    end
  end
end
