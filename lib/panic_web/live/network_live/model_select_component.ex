defmodule PanicWeb.NetworkLive.ModelSelectComponent do
  @moduledoc false
  use PanicWeb, :live_component

  import LiveSelect

  alias Panic.Model
  alias Phoenix.LiveView.JS

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Validity indicator and action buttons -->
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-4">
          <%= if @has_changes do %>
            <span class="text-sm text-zinc-400">Unsaved changes</span>
          <% end %>

          <div class="flex items-center gap-2">
            <%= if @validation_result == :valid do %>
              <.icon name="hero-check-circle" class="size-5 text-green-500" />
              <span class="text-sm text-green-500">Valid network</span>
            <% else %>
              <%= if @draft_models != [] do %>
                <.icon name="hero-exclamation-circle" class="size-5 text-red-500" />
                <span class="text-sm text-red-500">Invalid: {@validation_error}</span>
              <% end %>
            <% end %>
          </div>
        </div>

        <%= if @has_changes do %>
          <div class="flex gap-2">
            <button
              type="button"
              phx-click="reset_models"
              phx-target={@myself}
              class="px-4 py-2 text-sm bg-zinc-700 text-zinc-300 rounded hover:bg-zinc-600"
            >
              Reset
            </button>
            <button
              type="button"
              phx-click="save_models"
              phx-target={@myself}
              disabled={@validation_result != :valid}
              class={[
                "px-4 py-2 text-sm rounded",
                if @validation_result == :valid do
                  "bg-green-600 text-white hover:bg-green-700"
                else
                  "bg-zinc-700 text-zinc-500 cursor-not-allowed"
                end
              ]}
            >
              Save Network
            </button>
          </div>
        <% end %>
      </div>
      
    <!-- Model list -->
      <div class="flex items-center flex-wrap gap-6">
        <div class="size-8 rounded-md grid place-content-center text-center text-xs relative bg-zinc-600 shadow-sm">
          T
          <div class={[
            "size-6 absolute right-0 top-1/2 -translate-y-1/2 translate-x-1/2 -z-10",
            io_colour_mapper(:text)
          ]}>
          </div>
        </div>

        <%= for {model, index} <- Enum.with_index(@draft_models) do %>
          <.icon name="hero-arrow-right" class="size-4 text-white/50" />
          <button
            type="button"
            phx-click="remove_model"
            phx-value-index={index}
            phx-target={@myself}
            class="relative"
          >
            <div class="group">
              <div class="size-8 rounded-md grid place-content-center text-center text-xs relative bg-zinc-600 shadow-sm group-hover:bg-zinc-500">
                {abbreviate_model_name(model.name)}
                <div class={[
                  "size-6 absolute right-0 top-1/2 -translate-y-1/2 translate-x-1/2 -z-10",
                  io_colour_mapper(model.output_type)
                ]}>
                </div>
              </div>
              <.icon
                name="hero-x-mark"
                class="size-3 absolute -top-1 -right-1 text-zinc-300 bg-zinc-800 rounded-full p-0.5 hidden group-hover:block"
              />
            </div>
          </button>
        <% end %>

        <%= if @draft_models != [] do %>
          <.icon name="hero-arrow-right" class="size-4 text-white/50" />
          <div class={[
            "size-8 rounded-md grid place-content-center text-center text-xs relative bg-zinc-600 shadow-sm",
            "opacity-50"
          ]}>
            T
            <div class={[
              "size-6 absolute left-0 top-1/2 -translate-y-1/2 -translate-x-1/2 -z-10",
              io_colour_mapper(@next_input)
            ]}>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- LiveSelect input -->
      <.form for={@form} phx-change="change" phx-target={@myself}>
        <div id="model-select-wrapper" data-refocus={JS.focus(to: "#network_model_select_text_input")}>
          <.live_select
            field={@form[:model_select]}
            phx-target={@myself}
            id="model-select-input"
            mode={:single}
            options={@model_options}
            placeholder="Add model..."
            debounce={100}
            update_min_len={0}
            style={:none}
            container_class="relative"
            dropdown_class="absolute rounded-md shadow-lg z-50 bg-zinc-900 border border-zinc-700 inset-x-0 top-full mt-1 max-h-60 overflow-auto"
            option_class="px-4 py-2 text-zinc-300 cursor-pointer hover:bg-zinc-800"
            active_option_class="bg-violet-600 text-white"
            selected_option_class="font-bold text-violet-400"
            available_option_class="hover:bg-zinc-800"
            text_input_class="bg-zinc-800 border border-zinc-600 text-zinc-100 placeholder-zinc-500 rounded-md w-full px-3 py-2"
          />
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    saved_models = Enum.map(assigns.network.models, &Model.by_id!/1)

    # Initialize draft models from saved models if not already set
    draft_models =
      if Map.has_key?(socket.assigns, :draft_models) do
        socket.assigns.draft_models
      else
        saved_models
      end

    next_input = get_next_input_type(draft_models)
    model_options = get_model_options("", next_input)

    # Validate the current draft
    {validation_result, validation_error} = validate_network(draft_models)

    # Check if there are unsaved changes
    has_changes = draft_models != saved_models

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       saved_models: saved_models,
       draft_models: draft_models,
       next_input: next_input,
       model_options: model_options,
       validation_result: validation_result,
       validation_error: validation_error,
       has_changes: has_changes
     )
     |> assign_form()}
  end

  defp get_next_input_type([]), do: :text

  defp get_next_input_type(models) do
    %Model{output_type: type} = List.last(models)

    type
  end

  @impl true
  def handle_event("live_select_change", %{"text" => text, "id" => live_select_id}, socket) do
    model_options = get_model_options(text, socket.assigns.next_input)

    # Send updated options back to LiveSelect
    send_update(LiveSelect.Component, id: live_select_id, options: model_options)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change", params, socket) do
    # Handle selection from LiveSelect
    # LiveSelect sends both text_input and the actual value
    case params do
      %{"network" => %{"model_select" => model_id}} when model_id != "" and model_id != nil ->
        model = Model.by_id!(model_id)
        updated_models = socket.assigns.draft_models ++ [model]
        next_input = model.output_type
        model_options = get_model_options("", next_input)

        # Validate the updated draft
        {validation_result, validation_error} = validate_network(updated_models)
        has_changes = updated_models != socket.assigns.saved_models

        # Clear the LiveSelect input and update options for next input type
        send_update(LiveSelect.Component,
          id: "model-select-input",
          value: nil,
          options: model_options
        )

        {:noreply,
         socket
         |> assign(
           draft_models: updated_models,
           next_input: next_input,
           model_options: model_options,
           validation_result: validation_result,
           validation_error: validation_error,
           has_changes: has_changes
         )
         |> assign_form()
         |> push_event("js-exec", %{to: "#model-select-wrapper", attr: "data-refocus"})}

      _ ->
        # Ignore empty selections or text input changes
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_model", %{"index" => index}, socket) do
    updated_models = List.delete_at(socket.assigns.draft_models, String.to_integer(index))
    next_input = get_next_input_type(updated_models)
    model_options = get_model_options("", next_input)

    # Validate the updated draft
    {validation_result, validation_error} = validate_network(updated_models)
    has_changes = updated_models != socket.assigns.saved_models

    {:noreply,
     assign(socket,
       draft_models: updated_models,
       next_input: next_input,
       model_options: model_options,
       validation_result: validation_result,
       validation_error: validation_error,
       has_changes: has_changes
     )}
  end

  @impl true
  def handle_event("save_models", _params, socket) do
    # Only save if valid
    if socket.assigns.validation_result == :valid do
      model_ids = Enum.map(socket.assigns.draft_models, & &1.id)

      case Panic.Engine.update_models(socket.assigns.network, model_ids, actor: socket.assigns.current_user) do
        {:ok, updated_network} ->
          notify_parent({:models_updated, updated_network})

          {:noreply,
           socket
           |> assign(
             network: updated_network,
             saved_models: socket.assigns.draft_models,
             has_changes: false
           )
           |> assign_form()}

        {:error, %Ash.Error.Invalid{errors: errors}} ->
          # Extract the error message from the validation error
          error_message =
            errors
            |> Enum.map(& &1.message)
            |> Enum.filter(& &1)
            |> Enum.join(", ")
            |> case do
              "" -> "Failed to save models"
              msg -> msg
            end

          {:noreply, put_flash(socket, :error, error_message)}

        {:error, _error} ->
          # Generic error handling
          {:noreply, put_flash(socket, :error, "Failed to save models")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reset_models", _params, socket) do
    # Reset draft to saved state
    next_input = get_next_input_type(socket.assigns.saved_models)
    model_options = get_model_options("", next_input)
    {validation_result, validation_error} = validate_network(socket.assigns.saved_models)

    {:noreply,
     assign(socket,
       draft_models: socket.assigns.saved_models,
       next_input: next_input,
       model_options: model_options,
       validation_result: validation_result,
       validation_error: validation_error,
       has_changes: false
     )}
  end

  # Returns tuples {label, value} for LiveSelect compatibility
  defp get_model_options(search_term, input_type) do
    [input_type: input_type]
    |> Model.all()
    |> Enum.filter(fn model ->
      String.downcase(model.name) =~ String.downcase(search_term)
    end)
    |> Enum.map(fn model -> {model.name, model.id} end)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp io_colour_mapper(type) do
    case type do
      :text -> "bg-orange-500"
      :image -> "bg-blue-400"
      :audio -> "bg-emerald-800"
    end
  end

  defp abbreviate_model_name(name) do
    # For short names like "GPT-4", just use first 2-3 chars
    if String.length(name) <= 5 do
      String.slice(name, 0, 3)
    else
      # For longer names, use initials
      name
      |> String.split(" ")
      |> Enum.map_join(&String.at(&1, 0))
      |> String.upcase()
    end
  end

  defp assign_form(socket) do
    # Create a simple form just for the LiveSelect component
    # The actual update is handled via the code interface
    form = to_form(%{"model_select" => nil}, as: "network")
    assign(socket, form: form)
  end

  # Client-side validation of network models
  defp validate_network([]) do
    # Empty network is considered invalid but we don't show an error for it
    {:invalid, nil}
  end

  defp validate_network(models) do
    # Check sequential connections
    sequential_errors =
      [%{name: "Initial input", output_type: :text} | models]
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce([], fn
        [model1, model2], errors ->
          if model1.output_type == model2.input_type do
            errors
          else
            error =
              "#{model1.name} output (#{model1.output_type}) doesn't match #{model2.name} input (#{model2.input_type})"

            [error | errors]
          end
      end)

    # Check if the network forms a valid cycle
    first_model = List.first(models)
    last_model = List.last(models)

    cycle_errors =
      if last_model.output_type == first_model.input_type do
        []
      else
        [
          "Network doesn't form a cycle: #{last_model.name} output (#{last_model.output_type}) doesn't match #{first_model.name} input (#{first_model.input_type})"
        ]
      end

    case sequential_errors ++ cycle_errors do
      [] ->
        {:valid, nil}

      errors ->
        # Return the first error for display
        {:invalid, errors |> Enum.reverse() |> List.first()}
    end
  end
end
