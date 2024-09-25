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

  ## display grid/screens

  attr :invocations, :any, required: true, doc: "invocations stream"

  def display_grid(assigns) do
    ~H"""
    <ol id="current-inovocations" phx-update="stream">
      <li class="mb-4" :for={{id, invocation} <- @invocations} id={id}><%= invocation.model %> (<%= invocation.sequence_number%>): <%= invocation.output %></li>
    </ol>
    """
  end

  # individual components

  def invocation(assigns) do
    ~H"""
    <div class="p-4 text-base text-left">
      <%= for line <- String.split(@invocation.output, "\n\n") do %>
        <p :if={line != ""}><%= line %></p>
      <% end %>
    </div>
    """
  end

  def image_run(assigns) do
    ~H"""
    <div class="relative w-full">
      <img class="w-full object-cover" src={@run.output} />
      <span :if={false} class="absolute top-2 right-2 text-xl text-gray-300 text-right">
        <%= @run.model %>
      </span>
      <%= if @show_input do %>
        <span class="absolute left-[20px] bottom-[20px] text-2xl text-purple-700 text-left">
          <%= @run.input %>
        </span>
        <span class="absolute left-[21px] bottom-[21px] text-2xl text-purple-300 text-left">
          <%= @run.input %>
        </span>
      <% end %>
    </div>
    """
  end

  def audio_run(assigns) do
    ~H"""
    <audio autoplay controls={false} src={@run.output} />
    <%!-- volume_up --%>
    """
  end

  def running_run(assigns) do
    ~H"""
    <div class="absolute inset-0 animate-pulse bg-rose-600 grid place-items-center">
      <span class="text-black text-5xl">panic!</span>
    </div>
    """
  end

  def run(%{run: nil} = assigns) do
    ~H"""
    <div class="aspect-w-16 aspect-h-9 overflow-hidden relative block w-full text-center text-gray-400 bg-gray-900 shadow-lg">
      <div class="grid place-items-center">BLANK</div>
    </div>
    """
  end

  def run(assigns) do
    ~H"""
    <div class="aspect-w-16 aspect-h-9 overflow-hidden relative block w-full text-center text-gray-200 bg-gray-900 shadow-lg">
      <div class="absolute inset-0 grid place-items-center">
        <%= case @run.status do %>
          <% :created -> %>
            <%!-- minus_circle --%>
          <% :running -> %>
            <.running_run />
          <% :succeeded -> %>
            <%= case Models.model_io(@run.model) do %>
              <% {_, :text} -> %>
                <.text_run run={@run} />
              <% {_, :image} -> %>
                <.image_run run={@run} show_input={@show_input} />
              <% {_, :audio} -> %>
                <.audio_run run={@run} />
            <% end %>
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

  def slots_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-8 md:grid-cols-3">
      <%= for {run, _idx} <- Enum.with_index(@slots) do %>
        <.run run={run} show_input={false} />
      <% end %>
    </div>
    """
  end
end
