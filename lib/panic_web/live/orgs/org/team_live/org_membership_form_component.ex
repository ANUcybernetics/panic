defmodule PanicWeb.OrgTeamLive.OrgMembershipFormComponent do
  use PanicWeb, :live_component
  alias Panic.Orgs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        :let={f}
        id="form-membership"
        for={@changeset}
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
      >
        <.form_field
          type="radio_group"
          form={f}
          field={:role}
          label={gettext("Role")}
          options={@roles}
        />

        <%= if @membership.user_id == @current_membership.user_id && @membership.role == :admin do %>
          <.alert color="warning" class="my-5" heading={gettext("Be careful")}>
            <%= gettext("By removing yourself from admin you won't be able to regain access.") %>
          </.alert>
        <% end %>

        <div class="flex justify-end">
          <.button phx_disable_with={gettext("Saving...")}><%= gettext("Save") %></.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = Orgs.change_membership(assigns.membership)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:roles, Orgs.membership_roles() |> Enum.map(&{String.capitalize(&1), &1}))
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"membership" => params}, socket) do
    changeset =
      socket.assigns.membership
      |> Orgs.change_membership(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event(
        "save",
        %{"membership" => params},
        %{assigns: %{membership: membership}} = socket
      ) do
    case Orgs.update_membership(membership, params) do
      {:ok, membership} ->
        Panic.Logs.log("orgs.update_member", %{
          user: socket.assigns.current_user,
          target_user_id: membership.user_id,
          org_id: membership.org_id,
          metadata: %{
            role: membership.role
          }
        })

        {:noreply,
         socket
         |> put_flash(:info, gettext("Membership updated successfully"))
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
