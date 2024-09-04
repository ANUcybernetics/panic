defmodule PanicWeb.NetworkLive.ModelSelectComponent do
  use PanicWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@form} phx-change="change" phx-submit="save" phx-target={@myself}>
        <LiveSelect.live_select
          field={f[:model]}
          placeholder="Search for a model to append"
          phx-target={@myself}
        />

        <.button phx-disable-with="Adding model...">Add model</.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    next_input =
      case Enum.reverse(assigns.network.models) do
        [] -> :text
        [last | _] -> last.fetch!(:output_type)
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
  def handle_event("change", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"network" => %{"model" => model_name}}, socket) do
    # this _should_ be safe...
    model = String.to_atom(model_name)

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: %{model: model}
         ) do
      {:ok, network} ->
        notify_parent({:models_updated, network})

        socket =
          socket
          |> put_flash(:info, "Model appended successfully")
          |> assign(network: network)
          |> assign_form()

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{network: network}} = socket) do
    form =
      AshPhoenix.Form.for_update(network, :append_model,
        as: "network",
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end
end
