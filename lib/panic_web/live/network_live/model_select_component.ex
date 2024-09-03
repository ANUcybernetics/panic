defmodule PanicWeb.NetworkLive.ModelSelectComponent do
  use PanicWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@form} phx-submit="save">
        <LiveSelect.live_select
          field={f[:models]}
          mode={:tags}
          placeholder="Search for models to append"
          phx-target={@myself}
        />
        <.button type="submit">Add Models</.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    next_input =
      case Enum.reverse(assigns.network.models) do
        [] -> :text
        [last | _] -> last.fetch!(:input_type)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(next_input: next_input)
     |> assign_form()}
  end

  @impl true
  def handle_event("live_select_change", %{"text" => model_name, "id" => live_select_id}, socket) do
    model_options =
      Panic.Models.list(input_type: socket.assigns.next_input)
      |> Enum.filter(fn model ->
        String.downcase(model.fetch!(:name)) =~ String.downcase(model_name)
      end)
      |> Enum.map(fn model -> %{label: model.fetch!(:name), value: model} end)

    send_update(LiveSelect.Component, id: live_select_id, options: model_options)
    {:noreply, socket}
  end

  @impl true
  def handle_event("change", %{"network" => %{"models" => models}}, socket) do
    # list_of_coords will contain the list of the JSON-encoded coordinates of the selected cities, for example:
    # ["[-46.565,-23.69389]", "[-48.27722,-18.91861]"]
    dbg()

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"network" => network_params}, socket) do
    {:noreply,
     assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, network_params))}
  end

  @impl true
  def handle_event("save", %{"network" => network_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: network_params) do
      {:ok, _network} ->
        # notify_parent({:models_updated, network})

        socket =
          socket
          |> put_flash(:info, "Models updated successfully")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  # defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{network: network}} = socket) do
    form =
      AshPhoenix.Form.for_update(network, :update_models,
        as: "network",
        actor: socket.assigns[:current_user]
      )

    assign(socket, form: to_form(form))
  end
end
