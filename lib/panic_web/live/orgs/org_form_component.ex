defmodule PanicWeb.OrgFormComponent do
  use PanicWeb, :live_component
  alias Panic.Orgs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form let={f} for={@changeset} phx-target={@myself} phx-submit="save" phx-change="validate">
        <.form_field type="text_input" form={f} field={:name} {alpine_autofocus()} phx-debounce="500" />
        <.form_field type="text_input" disabled form={f} field={:slug} />

        <div class="flex justify-end gap-2">
          <.button phx_disable_with={gettext("Saving...")}>Save</.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{org: org} = assigns, socket) do
    changeset = Orgs.change_org(org, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"org" => org_params}, socket) do
    changeset =
      Orgs.change_org(socket.assigns.org, org_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"org" => org_params}, socket) do
    save_org(socket, socket.assigns.action, org_params)
  end

  defp save_org(socket, :edit, org_params) do
    case Orgs.update_org(socket.assigns.org, org_params) do
      {:ok, _org} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Organization updated successfully"))
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_org(socket, :new, org_params) do
    case Orgs.create_org(socket.assigns.current_user, org_params) do
      {:ok, _org} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Organization created successfully"))
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
