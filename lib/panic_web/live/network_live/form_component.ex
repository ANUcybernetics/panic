defmodule PanicWeb.NetworkLive.FormComponent do
  @moduledoc false
  use PanicWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
      </.header>

      <.form
        for={@form}
        id="network-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:lockout_seconds]} type="number" label="Lockout seconds" />
        <.input
          field={@form[:anon_terminal_minutes]}
          type="number"
          min="1"
          label="Anonymous terminal (minutes)"
        >
          <:help>
            Shows a QR code on the first screen of each of the network's installations, which lets anyone there prompt the network for this many minutes without signing in. Leave blank to turn it off.
          </:help>
        </.input>

        <div class="mt-6 flex flex-wrap gap-2">
          <.button variant="primary" phx-disable-with="Saving...">Save Network</.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"network" => network_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, network_params))}
  end

  def handle_event("save", %{"network" => network_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: network_params) do
      {:ok, network} ->
        notify_parent({:saved, network})

        socket =
          put_flash(socket, :info, "Network #{socket.assigns.form.source.type}d successfully")

        socket =
          if socket.assigns.navigate do
            redirect(socket, to: socket.assigns.navigate)
          else
            push_navigate(socket, to: ~p"/networks/#{network}")
          end

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{network: network}} = socket) do
    opts = [as: "network", actor: socket.assigns.current_user]

    form =
      if network,
        do: Panic.Engine.form_to_update_network(network, opts),
        else: Panic.Engine.form_to_create_network(opts)

    assign(socket, form: to_form(form))
  end
end
