defmodule PanicWeb.NetworkLive.ModelSelectComponent do
  use PanicWeb, :live_component
  import PanicWeb.PanicComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.model_list models={@models} phx_target={@myself} />

      <.form
        :let={f}
        class="mt-8"
        for={@form}
        phx-change="change"
        phx-submit="save"
        phx-target={@myself}
      >
        <LiveSelect.live_select
          field={f[:model]}
          placeholder="Search for a model to append"
          phx-target={@myself}
          phx-focus="populate_options"
        />

        <.button class="mt-4" phx-disable-with="Updating models...">Update models</.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    models = assigns.network.models
    next_input = get_next_input_type(models)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(models: models, next_input: next_input)
     |> assign_form()}
  end

  defp get_next_input_type([]), do: :text

  defp get_next_input_type(models) do
    List.last(models).fetch!(:output_type)
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
  def handle_event("change", %{"network" => %{"model" => model_name}}, socket) do
    model = String.to_existing_atom(model_name)
    updated_models = socket.assigns.models ++ [model]
    next_input = model.fetch!(:output_type)

    {:noreply, socket |> assign(models: updated_models, next_input: next_input)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    # ignoring the params here is a bit gross... perhaps there's a nice form-ier
    # way to do it with e.g. hidden inputs?
    case AshPhoenix.Form.submit(socket.assigns.form, params: %{models: socket.assigns.models}) do
      {:ok, updated_network} ->
        notify_parent({:models_updated, updated_network})

        {:noreply,
         socket
         |> put_flash(:info, "Models updated successfully")
         |> assign(network: updated_network, models: updated_network.models)
         |> assign_form()}

      {:error, form} ->
        {:noreply,
         socket
         # |> put_flash(:error, "Failed to update models: #{error_messages(form)}")
         |> assign(form: form)}
    end
  end

  @impl true
  def handle_event("remove_model", %{"index" => index}, socket) do
    updated_models = List.delete_at(socket.assigns.models, String.to_integer(index))
    {:noreply, assign(socket, models: updated_models)}
  end

  @impl true
  def handle_event("populate_options", _params, socket) do
    options = get_model_options("", socket.assigns.next_input)
    # hardcoded ID seems ok for now... not sure how else to do this "populate on focus" thing
    send_update(LiveSelect.Component, id: "network_model_live_select_component", options: options)
    {:noreply, socket}
  end

  defp get_model_options(search_term, input_type) do
    Panic.Models.list(input_type: input_type)
    |> Enum.filter(fn model ->
      String.downcase(model.fetch!(:name)) =~ String.downcase(search_term)
    end)
    |> Enum.map(fn model -> %{label: model.fetch!(:name), value: model} end)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{network: network}} = socket) do
    form =
      AshPhoenix.Form.for_update(network, :update_models,
        as: "network",
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end
end
