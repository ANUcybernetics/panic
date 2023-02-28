defmodule PanicWeb.NetworkComponents do
  @moduledoc """
  Provides the Network/Prediction UI components.

  Relies on PanicWeb.CoreComponents (which should be present in
  any view).

  """
  use Phoenix.Component
  import PanicWeb.CoreComponents

  alias Phoenix.LiveView.JS
  # import PanicWeb.Gettext

  alias Panic.Platforms
  alias Panic.Networks

  @doc """
  Renders a single prediction "card"

  The way the prediction is displayed depends on the input/output types of the
  model.

  """

  attr :prediction, :map, required: true

  attr :incoming, :boolean,
    default: false,
    doc: "is there a new prediction incoming into this slot soon?"

  def prediction_card(assigns) do
    ~H"""
    <.card>
      <%= case @prediction && Platforms.model_output_type(@prediction.model) do %>
        <% :text -> %>
          <.text_prediction text={@prediction.output} />
        <% :image -> %>
          <.image_prediction image_url={@prediction.output} />
        <% nil -> %>
          <.empty_slot />
      <% end %>
      <div :if={@prediction} class="absolute right-1 bottom-1">
        <%= strip_platform(@prediction.model) %>
      </div>
      <div :if={@incoming} class="absolute right-2 top-2">
        <.waiting_spinner size={:small} />
      </div>
    </.card>
    """
  end

  def card(assigns) do
    ~H"""
    <div class="aspect-w-16 aspect-h-9 overflow-hidden relative block w-full text-center text-gray-200 bg-gray-900 shadow-lg">
      <div class="absolute inset-0 grid place-items-center">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :genesis, :map, default: nil
  attr :predictions, :list, required: true

  attr :slot_incoming, :any,
    default: nil,
    doc: "index of the slot which has an incoming prediction, or `nil`"

  attr :class, :string, default: nil

  def prediction_grid(assigns) do
    ~H"""
    <section id={@id} class={[@class]}>
      <h2 class="text-md font-semibold">
        <span class="text-zinc-400">Initial input:</span><span :if={@genesis}> <%= @genesis.input %></span>
      </h2>
      <div class="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <.prediction_card
          :for={{prediction, idx} <- Enum.with_index(@predictions)}
          prediction={prediction}
          incoming={@slot_incoming && @slot_incoming == idx}
        />
      </div>
    </section>
    """
  end

  def text_prediction(assigns) do
    ~H"""
    <div class="p-4 text-base text-left">
      <%= for line <- String.split(@text, "\n\n") do %>
        <%= unless line == "" do %>
          <p class="text-purple-300"><%= line %></p>
        <% end %>
      <% end %>
    </div>
    """
  end

  def image_prediction(assigns) do
    ~H"""
    <div class="relative w-full">
      <img class="w-full object-cover" src={@image_url} />
    </div>
    """
  end

  def waiting_for_prediction(assigns) do
    ~H"""
    <span class="text-black text-5xl">panic!</span>
    """
  end

  def empty_slot(assigns) do
    ~H"""
    <span>BLANK</span>
    """
  end

  def model_description(assigns) do
    ~H"""
    <div class="flex">
      <div class="w-full md:w-1/3">
        <.prediction_card prediction={@prediction} />
      </div>
      <div class="grow">
        <h2 class="mb-4 font-semibold tracking-tight">
          <% @model |> Platforms.model_info() |> Map.get(:description) %>
        </h2>
        <p><% @model |> Platforms.model_info() |> Map.get(:description) %></p>
      </div>
    </div>
    """
  end

  @doc """
  A list of buttons for appending a model onto the network

  The buttons are "smart" in that only the models whose input type matches the
  output type of the last (current) model in the network will be enabled.

  """
  attr :network, :map, required: true
  attr :class, :string, default: nil

  def append_model_buttons(assigns) do
    ~H"""
    <section class={[@class]}>
      <h2 class="text-md font-semibold">Append Model</h2>
      <div class="mt-4 grid md:grid-cols-3 xl:grid-cols-6 gap-2">
        <.button
          :for={{model, %{name: name, input: input}} <- Platforms.all_model_info()}
          class="text-sm disabled:bg-zinc-300"
          disabled={input != Networks.last_model_output_type(@network)}
          phx-click={JS.push("append-model", value: %{model: model})}
        >
          <%= name %>
        </.button>
      </div>
    </section>
    """
  end

  @doc """
  A table of the models in the network.

  """
  attr :models, :list, required: true
  attr :table_id, :string, default: nil
  attr :class, :string, default: nil

  def network_models_table(assigns) do
    ~H"""
    <section class={[@class]}>
      <h2 class="text-md font-semibold">Network Models</h2>
      <.table id={@table_id} rows={models_and_last?(@models)}>
        <:col :let={{model, _last?}} label="Name">
          <%= model |> Platforms.model_info() |> Map.get(:name) %>
        </:col>
        <:action :let={{_model, last?}}>
          <.link :if={last?} phx-click={JS.push("remove-last-model")}>Remove</.link>
        </:action>
      </.table>
    </section>
    """
  end

  attr :state, :atom, required: true
  attr :missing_api_tokens, :list, required: true
  attr :api_navigate, :any, required: true
  attr :terminal_navigate, :any, required: true
  attr :network, :map, required: true
  attr :class, :string, default: nil

  def control_panel(assigns) do
    ~H"""
    <section class={["flex space-x-4", @class]}>
      <.button class={button_colour(@state)}><%= @state %></.button>
      <.button phx-click={JS.push("reset", value: %{network_id: @network.id})}>Reset</.button>
      <.button phx-click={JS.push("lock", value: %{network_id: @network.id})}>Lock</.button>
      <.link navigate={@api_navigate}>
        <.button class={(Enum.empty?(@missing_api_tokens) && "bg-emerald-500") || "bg-rose-600"}>
          API Tokens
        </.button>
      </.link>
      <.link navigate={@terminal_navigate}>
        <.button class="bg-red-700">Terminal</.button>
      </.link>
    </section>
    """
  end

  defp button_colour(:ready), do: "bg-pink-500"
  defp button_colour(state) when state in [:uninterruptable, :interruptable], do: "bg-emerald-500"
  defp button_colour(_state), do: "bg-zinc-900"

  attr :size, :atom, required: true

  def waiting_spinner(assigns) do
    ~H"""
    <div class="relative w-8 h-8">
      <div class="absolute rounded-full inset-0 z-50 animate-spin border-t-2 border-b-2 border-white/25">
      </div>
      <div class="absolute rounded-full inset-0 animate-pulse text-white bg-rose-600 grid place-items-center">
        P
      </div>
    </div>
    """
  end

  defp size_classes(:small), do: "w-6 h-6 text-xs"
  defp size_classes(:medium), do: "w-12 h-12 text-sm"
  defp size_classes(:large), do: "w-24 h-24 text-lg"

  defp models_and_last?(models) do
    last_idx = Enum.count(models) - 1
    Enum.with_index(models, fn model, i -> {model, i == last_idx} end)
  end

  defp strip_platform(model) do
    model |> String.split(~r/[:\/]/) |> List.last()
  end
end
