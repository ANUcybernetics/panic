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
  alias Panic.Networks.Network

  @doc """
  Renders a single prediction "card"

  The way the prediction is displayed depends on the input/output types of the
  model.

  """

  ## not really a map
  attr :prediction, :map, required: true

  def prediction_card(assigns) do
    ~H"""
    <.card>
      <%= case Platforms.model_output_type(@prediction.model) do %>
        <% :text -> %>
          <.text_prediction text={@prediction.output} />
        <% :image -> %>
          <.image_prediction image_url={@prediction.output} />
      <% end %>
      <div class="absolute right-2 bottom-2">
        <%= strip_platform(@prediction.model) %>
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

  def prediction_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-8 md:grid-cols-3 xl:grid-cols-6">
      <.prediction_card :for={prediction <- @predictions} prediction={prediction} />
    </div>
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

  ## input prompt is always text
  defp last_model_output_type(%Network{models: []}), do: :text

  defp last_model_output_type(%Network{models: models}),
    do: models |> List.last() |> Platforms.model_info() |> Map.get(:output)

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
          class="disabled:bg-zinc-300"
          disabled={input != last_model_output_type(@network)}
          phx-click={JS.push("append-model", value: %{model: model})}
        >
          <%= name %>
        </.button>
      </div>
      <.button class="mt-4 bg-rose-300" phx-click="remove-last-model">
        Remove last
      </.button>
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
        <:action :let={{model, last?}}>
          <.link :if={last?} phx-click={JS.push("remove-last-model")}>Remove</.link>
        </:action>
      </.table>
    </section>
    """
  end

  defp models_and_last?(models) do
    last_idx = Enum.count(models) - 1
    Enum.with_index(models, fn model, i -> {model, i == last_idx} end)
  end

  defp strip_platform(model) do
    model |> String.split(~r/[:\/]/) |> List.last()
  end
end
