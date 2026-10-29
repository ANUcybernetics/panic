defmodule PanicWeb.NetworkLive.ModelSelectComponent do
  @moduledoc false
  use PanicWeb, :live_component

  alias Panic.Model
  alias Phoenix.LiveView.JS

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
          <span :if={@has_changes} class="text-base-content/60">Unsaved changes</span>

          <div :if={@validation_result == :valid} class="flex items-center gap-2 text-success">
            <.icon name="hero-check-circle" class="size-5" />
            <span>Valid network</span>
          </div>
          <div
            :if={@validation_result != :valid and @draft_models != []}
            class="flex items-center gap-2 text-error"
          >
            <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
            <span>Invalid: {@validation_error}</span>
          </div>
        </div>

        <div :if={@has_changes} class="flex gap-2">
          <button
            type="button"
            phx-click="reset_models"
            phx-target={@myself}
            class="btn btn-sm btn-ghost"
          >
            Reset
          </button>
          <button
            type="button"
            phx-click="save_models"
            phx-target={@myself}
            disabled={@validation_result != :valid}
            class="btn btn-sm btn-success"
          >
            Save Network
          </button>
        </div>
      </div>

      <div :if={@draft_models != []} class="overflow-x-auto rounded-box border border-base-300">
        <table class="table">
          <thead>
            <tr>
              <th class="w-0">#</th>
              <th>Model</th>
              <th class="hidden sm:table-cell">Type</th>
              <th class="w-0"><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{model, index} <- Enum.with_index(@draft_models)}>
              <td class="text-base-content/60">{index}</td>
              <td>
                {model.name}
                <span class={[
                  "badge badge-sm mt-1 block w-fit sm:hidden",
                  type_badge_class(model.input_type, model.output_type)
                ]}>
                  {model.input_type} → {model.output_type}
                </span>
              </td>
              <td class="hidden sm:table-cell">
                <span class={[
                  "badge badge-sm whitespace-nowrap",
                  type_badge_class(model.input_type, model.output_type)
                ]}>
                  {model.input_type} → {model.output_type}
                </span>
              </td>
              <td>
                <div class="flex items-center justify-end">
                  <button
                    type="button"
                    phx-click="move_model_up"
                    phx-value-index={index}
                    phx-target={@myself}
                    disabled={index == 0}
                    class="btn btn-ghost btn-square btn-sm"
                    aria-label="Move up"
                  >
                    <.icon name="hero-chevron-up" />
                  </button>
                  <button
                    type="button"
                    phx-click="move_model_down"
                    phx-value-index={index}
                    phx-target={@myself}
                    disabled={index == length(@draft_models) - 1}
                    class="btn btn-ghost btn-square btn-sm"
                    aria-label="Move down"
                  >
                    <.icon name="hero-chevron-down" />
                  </button>
                  <button
                    type="button"
                    phx-click="remove_model"
                    phx-value-index={index}
                    phx-target={@myself}
                    class="btn btn-ghost btn-square btn-sm hover:text-error"
                    aria-label="Remove"
                  >
                    <.icon name="hero-trash" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div :if={@draft_models == []} class="py-8 text-center text-base-content/60">
        No models in network. Add a model below to get started.
      </div>

      <.form for={%{}} id="model-picker" phx-change="search" phx-submit="add" phx-target={@myself}>
        <label for={picker_id(@picks)} class="sr-only">Add model</label>
        <input
          id={picker_id(@picks)}
          name="model"
          type="text"
          list="model-options"
          autocomplete="off"
          placeholder={"Add a model that takes #{@next_input}..."}
          phx-mounted={if @picks > 0, do: JS.focus()}
          class="input w-full"
        />
        <datalist id="model-options">
          <option :for={model <- @candidates} value={model.name} />
        </datalist>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    saved_models = assigns.network.models |> Enum.map(&Model.by_id/1) |> Enum.reject(&is_nil/1)

    {:ok,
     socket
     |> assign(saved_models: saved_models)
     |> assign_new(:picks, fn -> 0 end)
     |> assign_draft(socket.assigns[:draft_models] || saved_models)}
  end

  @impl true
  # picking from the datalist fills in a model's full name, which adds it
  def handle_event("search", %{"model" => text}, socket) do
    case exact_match(socket.assigns.candidates, text) do
      %Model{} = model -> {:noreply, add_model(socket, model)}
      nil -> {:noreply, socket}
    end
  end

  # Enter adds the exact match, or the only candidate containing the text
  def handle_event("add", %{"model" => text}, socket) do
    candidates = socket.assigns.candidates

    case {exact_match(candidates, text), Enum.filter(candidates, &contains?(text, &1.name))} do
      {%Model{} = model, _} -> {:noreply, add_model(socket, model)}
      {nil, [model]} -> {:noreply, add_model(socket, model)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("remove_model", %{"index" => index}, socket) do
    {:noreply, assign_draft(socket, List.delete_at(socket.assigns.draft_models, String.to_integer(index)))}
  end

  def handle_event("move_model_up", %{"index" => index}, socket) do
    {:noreply, move(socket, String.to_integer(index), -1)}
  end

  def handle_event("move_model_down", %{"index" => index}, socket) do
    {:noreply, move(socket, String.to_integer(index), 1)}
  end

  def handle_event("reset_models", _params, socket) do
    {:noreply, assign_draft(socket, socket.assigns.saved_models)}
  end

  def handle_event("save_models", _params, %{assigns: %{validation_result: :valid}} = socket) do
    model_ids = Enum.map(socket.assigns.draft_models, & &1.id)

    case Panic.Engine.update_models(socket.assigns.network, model_ids, actor: socket.assigns.current_user) do
      {:ok, updated_network} ->
        notify_parent({:models_updated, updated_network})

        {:noreply,
         assign(socket,
           network: updated_network,
           saved_models: socket.assigns.draft_models,
           has_changes: false
         )}

      {:error, error} ->
        message =
          error
          |> Ash.Error.to_error_class()
          |> Map.get(:errors, [])
          |> Enum.map_join(", ", &Exception.message/1)

        {:noreply, put_flash(socket, :error, if(message == "", do: "Failed to save models", else: message))}
    end
  end

  def handle_event("save_models", _params, socket), do: {:noreply, socket}

  # a new input id swaps in a fresh, empty input (LiveView won't clear the
  # value of a focused one), and phx-mounted focuses it for the next pick
  defp add_model(socket, model) do
    socket
    |> update(:picks, &(&1 + 1))
    |> assign_draft(socket.assigns.draft_models ++ [model])
  end

  defp picker_id(picks), do: "model-picker-input-#{picks}"

  defp move(socket, index, offset) do
    models = socket.assigns.draft_models
    other = index + offset

    if other in 0..(length(models) - 1)//1 do
      swapped =
        models
        |> List.replace_at(index, Enum.at(models, other))
        |> List.replace_at(other, Enum.at(models, index))

      assign_draft(socket, swapped)
    else
      socket
    end
  end

  defp assign_draft(socket, models) do
    next_input = next_input_type(models)
    {validation_result, validation_error} = validate_network(models)

    assign(socket,
      draft_models: models,
      next_input: next_input,
      candidates: candidates(next_input),
      validation_result: validation_result,
      validation_error: validation_error,
      has_changes: models != socket.assigns.saved_models
    )
  end

  defp next_input_type([]), do: :text
  defp next_input_type(models), do: List.last(models).output_type

  # the models that can follow one with this output type
  defp candidates(input_type) do
    [input_type: input_type] |> Model.all() |> Enum.reject(& &1.deprecated)
  end

  defp exact_match(candidates, text) do
    text = text |> String.trim() |> String.downcase()
    Enum.find(candidates, &(String.downcase(&1.name) == text))
  end

  defp contains?(text, name) do
    text = text |> String.trim() |> String.downcase()
    text != "" and String.contains?(String.downcase(name), text)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp type_badge_class(input_type, output_type) do
    # Determine background color based on input/output types
    bg_color =
      case {input_type, output_type} do
        {:text, :text} -> "bg-orange-500/20 text-orange-400 border border-orange-500/30"
        {:text, :image} -> "bg-blue-400/20 text-blue-400 border border-blue-400/30"
        {:text, :audio} -> "bg-emerald-600/20 text-emerald-400 border border-emerald-600/30"
        {:image, :text} -> "bg-violet-500/20 text-violet-400 border border-violet-500/30"
        {:audio, :text} -> "bg-pink-500/20 text-pink-400 border border-pink-500/30"
        {:image, :image} -> "bg-blue-400/20 text-blue-400 border border-blue-400/30"
        {:audio, :audio} -> "bg-emerald-600/20 text-emerald-400 border border-emerald-600/30"
        _ -> "bg-zinc-600/20 text-zinc-400 border border-zinc-600/30"
      end

    bg_color
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
