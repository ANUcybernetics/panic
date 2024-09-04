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
    ~H"""
    <div class="w-16 h-16 rounded-md grid place-content-center text-center text-xs relative">
      <div class={[
        "w-3 h-3 rounded-full absolute left-0 top-1/2 -translate-y-1/2",
        @model.fetch!(:input_type) |> io_colour_mapper()
      ]}>
      </div>
      <%= @model.fetch!(:name) %>
      <div class={[
        "w-3 h-3 rounded-full absolute right-0 top-1/2 -translate-y-1/2",
        @model.fetch!(:output_type) |> io_colour_mapper()
      ]}>
      </div>
    </div>
    """
  end

  defp io_colour_mapper(:text), do: "bg-purple-500"
  defp io_colour_mapper(:image), do: "bg-green-500"
  defp io_colour_mapper(:audio), do: "bg-purple-500"
end
