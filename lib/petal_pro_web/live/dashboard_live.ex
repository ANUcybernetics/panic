defmodule PetalProWeb.DashboardLive do
  use PetalProWeb, :live_view
  alias PetalPro.{Orgs, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_invitations()

    {:ok, socket}
  end

  @impl true
  def handle_event("confirmation_resend", _, socket) do
    socket.assigns.current_user
    |> Accounts.deliver_user_confirmation_instructions(
      &Routes.user_confirmation_url(socket, :edit, &1)
    )

    {:noreply,
     socket
     |> put_flash(:info, gettext("You will receive an e-mail with instructions shortly."))}
  end

  defp assign_invitations(socket) do
    invitations = Orgs.list_invitations_by_user(socket.assigns.current_user)

    assign(socket, :invitations, invitations)
  end
end
