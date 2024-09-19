defmodule PanicWeb.PanicComponents do
  @moduledoc """
  Provides Panic-specific UI components.

  Because this module imports the (template-provided) `PanicWeb.CoreComponents`,
  the main PanicWeb helpers have been modified to import _this_ module instead
  (to avoid circular dep issues).
  """
  use Phoenix.Component
  # import PanicWeb.CoreComponents

  @doc """
  Renders a model box.

  Useful for displaying a representation of a model (e.g. in a "network list")
  component.
  """
  attr :model, :any, required: true, doc: "Panic.Model struct"
  slot :action, doc: "the slot for showing user actions in the model box"

  def model_box(assigns) do
    ~H"""
    <div class="size-16 rounded-md grid place-content-center text-center text-xs relative bg-gray-200 shadow-sm">
      <div class={[
        "size-6 absolute left-0 top-1/2 -translate-y-1/2 -translate-x-1/2 -z-10",
        io_colour_mapper(@model, :input_type)
      ]}>
      </div>
      <%= @model.name %>
      <div class={[
        "size-6 absolute right-0 top-1/2 -translate-y-1/2 translate-x-1/2 -z-10",
        io_colour_mapper(@model, :output_type)
      ]}>
      </div>
      <%= render_slot(@action) %>
    </div>
    """
  end

  @doc """
  Renders a list of models in a flexbox layout.

  ## Examples

      <.model_list models={@models} />
  """
  attr :models, :list, required: true, doc: "List of Panic.Model structs"

  attr :phx_target, :any, default: nil

  def model_list(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-6 border-2 p-2 rounded-md">
      <div class="size-16 rounded-md grid place-content-center text-center text-xs relative bg-gray-100 shadow-sm">
        T
        <div class={[
          "size-6 absolute right-0 top-1/2 -translate-y-1/2 translate-x-1/2 -z-10",
          io_colour_mapper(nil, :input_type)
        ]}>
        </div>
      </div>
      <%= for {model, idx} <- Enum.with_index(@models) do %>
        <.model_box model={model}>
          <:action>
            <button
              phx-click="remove_model"
              phx-value-index={idx}
              phx-target={@phx_target}
              class="absolute size-4 top-0 right-0 text-xs text-gray-500 hover:text-gray-700"
            >
              ×
            </button>
          </:action>
        </.model_box>
      <% end %>
    </div>
    """
  end

  # a hack to handle the "first model" case
  defp io_colour_mapper(nil, :input_type), do: "bg-purple-500"

  defp io_colour_mapper(model, key) do
    case model[key] do
      :text -> "bg-purple-500"
      :image -> "bg-green-500"
      :audio -> "bg-purple-500"
    end
  end
end
