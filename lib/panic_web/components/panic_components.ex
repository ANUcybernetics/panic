defmodule PanicWeb.PanicComponents do
  @moduledoc """
  Provides Panic-specific UI components.

  Because this module imports the (template-provided) `PanicWeb.CoreComponents`,
  the main PanicWeb helpers have been modified to import _this_ module instead
  (to avoid circular dep issues).
  """
  use Phoenix.Component

  alias Panic.Engine.Invocation
  alias Panic.Model

  @doc """
  Renders a model box.

  Useful for displaying a representation of a model (e.g. in a "network list")
  component.
  """
  attr :model, :any, required: true, doc: "Panic.Model struct"
  slot :action, doc: "the slot for showing user actions in the model box"

  def model_box(assigns) do
    ~H"""
    <div class="size-16 rounded-md grid place-content-center text-center text-xs relative bg-zinc-600 shadow-sm">
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
    <div class="flex items-center flex-wrap gap-6">
      <div class="size-8 rounded-md grid place-content-center text-center text-xs relative bg-zinc-600 shadow-sm">
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
      :audio -> "bg-teal-600"
    end
  end

  ## display grid/screens

  attr :invocations, :any, required: true, doc: "invocations stream"
  attr :display, :any, required: true, doc: "the grid tuple: {:grid, row, col} or {:single, offset, stride}"

  def display(assigns) do
    ~H"""
    <div
      id="current-inovocations"
      class={"grid gap-4 grid-cols-#{num_cols(@display)}"}
      phx-update="stream"
    >
      <.invocation
        :for={{id, invocation} <- @invocations}
        id={id}
        invocation={invocation}
        model={invocation.model |> List.last() |> Model.by_id!()}
      />
    </div>
    """
  end

  defp num_cols({:grid, _rows, cols}), do: cols
  defp num_cols({:single, _, _}), do: 1

  # individual components

  attr :id, :string, required: true
  slot :inner_block, required: true
  slot :input, doc: "Optional input to render in the top left corner"

  def invocation_container(assigns) do
    ~H"""
    <div id={@id} class="relative aspect-video overflow-hidden">
      <%= render_slot(@inner_block) %>
      <%= if @input && false do %>
        <div class="absolute top-0 left-0 aspect-video h-1/3">
          <%= render_slot(@input) %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :invocation, :any, required: true, doc: "Panic.Engine.Invocation struct"
  attr :model, :any, required: true, doc: "Panic.Model struct"
  attr :id, :string, required: true

  def invocation(%{invocation: %Invocation{state: :failed}} = assigns) do
    ~H"""
    <.invocation_container id={@id}>
      <p class="size-full grid place-items-center bg-rose-500">failed</p>
    </.invocation_container>
    """
  end

  def invocation(%{invocation: %Invocation{state: :invoking}} = assigns) do
    ~H"""
    <.invocation_container id={@id}>
      <p class="size-full grid place-items-center animate-pulse bg-yellow-300">PANIC!</p>
    </.invocation_container>
    """
  end

  def invocation(assigns) do
    ~H"""
    <.invocation_container id={@id}>
      <.invocation_slot id={@id} type={@model.output_type} value={@invocation.output} />
      <:input>
        <.invocation_slot type={@model.input_type} value={@invocation.input} />
      </:input>
    </.invocation_container>
    """
  end

  attr :type, :atom, required: true, doc: "the type (modality) of the invocation input or output"
  attr :value, :string, required: true, doc: "the value of the invocation input or output"
  attr :id, :string

  def invocation_slot(%{type: :text} = assigns) do
    ~H"""
    <div class="size-full grid place-items-center p-1 text-sm text-left">
      <div>
        <%= for line <- String.split(@value, "\n\n") do %>
          <.shadowed_text :if={line != ""}><%= line %></.shadowed_text>
        <% end %>
      </div>
    </div>
    """
  end

  def invocation_slot(%{type: :image} = assigns) do
    ~H"""
    <img class="object-cover w-full" src={@value} />
    """
  end

  def invocation_slot(%{type: :audio} = assigns) do
    ~H"""
    <div
      class="relative size-full bg-teal-600"
      id={"#{@id}-audio-visualizer"}
      phx-hook="AudioVisualizer"
      data-audio-src={@value}
    >
      <div class="visualizer-container absolute inset-0"></div>
    </div>
    """
  end

  # #581c87 is purple-900
  def shadowed_text(assigns) do
    ~H"""
    <p class="[text-shadow:2px_2px_0px_#581c87]">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  def run(assigns) do
    ~H"""
    <div class="aspect-w-16 aspect-h-9 overflow-hidden relative block w-full text-center text-gray-200 bg-gray-900 shadow-lg">
      <div class="absolute inset-0 grid place-items-center">
        <%= case @run.status do %>
          <% :created -> %>
            <%!-- minus_circle --%>
          <% :succeeded -> %>
            text run
          <% :failed -> %>
            <%!-- x_circle --%>
        <% end %>
        <div class="absolute left-2 -bottom-6">
          <%= @run.model |> String.split(~r/[:\/]/) |> List.last() %>
        </div>
      </div>
    </div>
    """
  end
end
