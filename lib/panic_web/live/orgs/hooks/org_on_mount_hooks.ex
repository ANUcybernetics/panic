defmodule PanicWeb.OrgOnMountHooks do
  @moduledoc """
  Org related on_mount hooks used by live views. These are used in the router or within a specific live view if need be.
  Docs: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1
  """
  import Phoenix.LiveView
  import Phoenix.Component
  import PanicWeb.Gettext
  alias Panic.Orgs

  def on_mount(:assign_org_data, params, _session, socket) do
    socket =
      socket
      |> assign_orgs()
      |> assign_current_membership(params)
      |> assign_current_org()

    {:cont, socket}
  end

  def on_mount(:require_org_member, _params, _session, socket) do
    if socket.assigns[:current_membership] do
      {:cont, socket}
    else
      socket =
        put_flash(socket, :error, gettext("You do not have permission to access this page."))

      {:halt, redirect(socket, to: PanicWeb.Helpers.home_path(socket.assigns.current_user))}
    end
  end

  def on_mount(:require_org_admin, _params, _session, socket) do
    if socket.assigns[:current_membership] && socket.assigns.current_membership.role == :admin do
      {:cont, socket}
    else
      socket =
        put_flash(socket, :error, gettext("You do not have permission to access this page."))

      {:halt, redirect(socket, to: PanicWeb.Helpers.home_path(socket.assigns.current_user))}
    end
  end

  def assign_orgs(socket) do
    assign_new(socket, :orgs, fn ->
      socket.assigns[:current_user] && Orgs.list_orgs(socket.assigns.current_user)
    end)
  end

  defp assign_current_membership(socket, params) do
    assign_new(socket, :current_membership, fn ->
      params["org_slug"] && Orgs.get_membership!(socket.assigns.current_user, params["org_slug"])
    end)
  end

  defp assign_current_org(socket) do
    assign_new(socket, :current_org, fn ->
      membership = socket.assigns.current_membership
      membership && membership.org
    end)
  end
end
