defmodule PanicWeb.UserOrgInvitationsLive do
  use PanicWeb, :live_view
  import PanicWeb.UserSettingsLayoutComponent
  alias Panic.{Orgs, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_invitations()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_layout current={:org_invitations} current_user={@current_user}>
      <%= if @current_user.confirmed_at do %>
        <%= if Util.blank?(@invitations) do %>
          <.p>
            <%= gettext("You have no pending invitations.") %>
          </.p>
        <% else %>
          <div class="grid grid-cols-1 mt-6 md:grid-cols-2 xl:grid-cols-3">
            <%= for invitation <- @invitations do %>
              <.box padded id={"invitation-#{invitation.id}"}>
                <div>
                  <div class="flex items-center justify-center w-12 h-12 mx-auto bg-blue-100 rounded-full">
                    <Heroicons.Outline.mail class="w-6 h-6 text-blue-600" />
                  </div>
                  <div class="mt-3 text-center sm:mt-5">
                    <div class="text-lg font-medium leading-6 text-gray-900 dark:text-white">
                      <%= gettext("Invitation") %>
                    </div>
                    <div class="mt-2">
                      <div class="text-sm text-gray-500 dark:text-gray-400">
                        <%= gettext("You have been invited to join %{org_name}",
                          org_name: invitation.org.name
                        ) %>.
                      </div>
                    </div>
                  </div>
                </div>
                <div class="mt-5 sm:mt-6">
                  <div class="mt-5 sm:mt-6 sm:grid sm:grid-cols-2 sm:gap-3 sm:grid-flow-row-dense">
                    <.button
                      phx-click="reject_invitation"
                      phx-value-id={invitation.id}
                      label={gettext("Reject")}
                      data-confirm={gettext("Are you sure you want to reject this invitation?")}
                      color="white"
                    />

                    <.button
                      phx-click="accept_invitation"
                      phx-value-id={invitation.id}
                      label={gettext("Accept")}
                      color="primary"
                    />
                  </div>
                </div>
              </.box>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <.alert color="warning" class="my-5" heading={gettext("Unconfirmed account")}>
          <%= gettext(
            "You may have pending invitations. To see them please confirm your account by clicking the link in the e-mail we sent you. If you didn't receive an e-mail,"
          ) %>
          <a href="#" phx-click="confirmation_resend" class="underline">
            <%= gettext("click here to resend it") %>.
          </a>
        </.alert>
      <% end %>
    </.settings_layout>
    """
  end

  @impl true
  def handle_event("accept_invitation", %{"id" => id}, socket) do
    membership = Orgs.accept_invitation!(socket.assigns.current_user, id)

    Panic.Logs.log("orgs.accept_invitation", %{
      user: socket.assigns.current_user,
      org_id: membership.org_id,
      metadata: %{
        membership_id: membership.id
      }
    })

    {:noreply,
     socket
     |> put_flash(:info, gettext("Invitation was accepted"))
     |> assign_invitations()}
  end

  @impl true
  def handle_event("reject_invitation", %{"id" => id}, socket) do
    invitation = Orgs.reject_invitation!(socket.assigns.current_user, id)

    Panic.Logs.log("orgs.reject_invitation", %{
      user: socket.assigns.current_user,
      org_id: invitation.org_id
    })

    {:noreply,
     socket
     |> put_flash(:info, gettext("Invitation was rejected"))
     |> assign_invitations()}
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
