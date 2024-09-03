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

  attr :model, :atom, required: true, doc: "module which implements Panic.Model behaviour"

  def model_box(assigns) do
    model = assigns.model

    input_type = model.fetch!(:input_type)
    output_type = model.fetch!(:output_type)
    name = model.fetch!(:name)

    border_color =
      case {input_type, output_type} do
        {:text, :text} -> "border-blue-500"
        {:image, :text} -> "border-green-500"
        {:text, :image} -> "border-purple-500"
        {:image, :image} -> "border-orange-500"
        _ -> "border-gray-500"
      end

    ~H"""
    <div class={"w-16 h-16 rounded-md grid place-content-center text-center text-xs border-l-4 border-r-4 #{border_color}"}>
      <%= name %>
    </div>
    """
  end
end
