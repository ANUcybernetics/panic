defmodule PanicWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  use PanicWeb, :verified_routes

  import Phoenix.Component

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_admin_required, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %{admin: true} ->
        {:cont, socket}

      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      _user ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Only admins can access that page")
         |> Phoenix.LiveView.redirect(to: ~p"/")}
    end
  end
end
