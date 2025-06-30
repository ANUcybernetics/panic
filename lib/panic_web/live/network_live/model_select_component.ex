defmodule PanicWeb.NetworkLive.ModelSelectComponent do
  @moduledoc false
  use PanicWeb, :live_component

  import AutocompleteInput
  import PanicWeb.PanicComponents

  alias Panic.Model

  # AIDEV-NOTE: Refactored from LiveSelect to AutocompleteInput for model selection
  # AutocompleteInput provides better UX with search filtering and commit-based selection

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.model_list models={@models} phx_target={@myself} />

      <.form class="mt-8" for={@form} phx-change="change" phx-submit="save" phx-target={@myself}>
        <label for="network_model_autocomplete">Add model</label>
        <.autocomplete_input
          id="network_model_autocomplete"
          name="model"
          options={@model_options}
          value=""
          display_value="Search for a model to append"
          min_length={1}
        />

        <.button class="mt-4" phx-disable-with="Updating models...">Update models</.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    models = Model.model_ids_to_model_list(assigns.network.models)
    next_input = get_next_input_type(models)
    model_options = get_model_options("", next_input)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(models: models, next_input: next_input, model_options: model_options)
     |> assign_form()}
  end

  defp get_next_input_type([]), do: :text

  defp get_next_input_type(models) do
    %Model{output_type: type} = List.last(models)

    type
  end

  @impl true
  def handle_event("autocomplete-search", %{"name" => "model", "query" => query}, socket) do
    model_options = get_model_options(query, socket.assigns.next_input)
    {:noreply, assign(socket, model_options: model_options)}
  end

  @impl true
  def handle_event("autocomplete-commit", %{"name" => "model", "value" => model_id}, socket) do
    model = Model.by_id!(model_id)
    updated_models = socket.assigns.models ++ [model]
    next_input = model.output_type
    model_options = get_model_options("", next_input)

    {:noreply, assign(socket, models: updated_models, next_input: next_input, model_options: model_options)}
  end

  @impl true
  def handle_event("autocomplete-close", %{"name" => "model"}, socket) do
    # Clear options when autocomplete closes
    {:noreply, assign(socket, model_options: [])}
  end

  @impl true
  def handle_event("save", _params, socket) do
    # Convert model structs to IDs before submission
    model_ids = Model.model_list_to_model_ids(socket.assigns.models)

    case AshPhoenix.Form.submit(socket.assigns.form, params: %{models: model_ids}) do
      {:ok, updated_network} ->
        notify_parent({:models_updated, updated_network})

        {:noreply,
         socket
         |> put_flash(:info, "Models updated successfully")
         |> assign(network: updated_network)
         |> assign_form()}

      {:error, form} ->
        {
          :noreply,
          assign(socket, form: form)
          # |> put_flash(:error, "Failed to update models: #{error_messages(form)}")
        }
    end
  end

  @impl true
  def handle_event("remove_model", %{"index" => index}, socket) do
    updated_models = List.delete_at(socket.assigns.models, String.to_integer(index))
    next_input = get_next_input_type(updated_models)
    model_options = get_model_options("", next_input)
    {:noreply, assign(socket, models: updated_models, next_input: next_input, model_options: model_options)}
  end

  @impl true
  def handle_event("autocomplete-open", %{"name" => "model"}, socket) do
    model_options = get_model_options("", socket.assigns.next_input)
    {:noreply, assign(socket, model_options: model_options)}
  end

  defp get_model_options(search_term, input_type) do
    [input_type: input_type]
    |> Model.all()
    |> Enum.filter(fn model ->
      String.downcase(model.name) =~ String.downcase(search_term)
    end)
    |> Enum.map(fn model -> %{label: model.name, value: model.id} end)
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
