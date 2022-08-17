defmodule PanicWeb.NetworkLive.FormComponent do
  use PanicWeb, :live_component

  alias Panic.{Models, Networks}

  @impl true
  def update(%{network: network} = assigns, socket) do
    changeset = Networks.change_network(network)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"network" => network_params}, socket) do
    changeset =
      socket.assigns.network
      |> Networks.change_network(network_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"network" => network_params}, socket) do
    case Networks.create_network(network_params) do
      {:ok, _network} ->
        {:noreply,
         socket
         |> put_flash(:info, "Network created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        let={f}
        for={@changeset}
        id="new-network-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.form_field type="text_input" form={f} field={:name} />
        <.button type="submit" phx_disable_with="Saving..." label="Save" />
      </.form>
    </div>
    """
  end
end
