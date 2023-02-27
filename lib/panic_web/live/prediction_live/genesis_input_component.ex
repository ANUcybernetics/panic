defmodule PanicWeb.PredictionLive.GensisInputComponent do
  @moduledoc """
  The main Panic "input terminal".

  The form her is so simple (just a text input) that it doesn't do the usual
  changeset thing; it just grabs the input string and dispatches it straight to
  `Predictions.create_prediction_async/3`.

  """
  use PanicWeb, :live_component
  alias Panic.Predictions

  attr :panic_button?, :boolean, default: false
  attr :class, :string, default: nil

  def render(assigns) do
    ~H"""
    <section class={[@class]}>
      <.simple_form for={@form} id={@id} phx-target={@myself} phx-submit="new-genesis-input">
        <.input field={@form[:input]} type="text" label="Input" />
        <:actions>
          <.button
            :if={@panic_button?}
            class="mt-16 w-64 h-64 mx-auto rounded-full text-4xl text-white bg-red-700"
            phx-disable-with="Panicking..."
          >
            Panic
          </.button>
        </:actions>
      </.simple_form>
    </section>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn -> empty_form() end)}
  end

  @impl true
  def handle_event("new-genesis-input", %{"prediction" => %{"input" => ""}}, socket),
    do: {:noreply, socket}

  @impl true
  def handle_event("new-genesis-input", %{"prediction" => %{"input" => input}}, socket) do
    send(self(), {:genesis_input, input})
    {:noreply, assign(socket, form: empty_form())}
  end

  defp empty_form() do
    %Predictions.Prediction{}
    |> Predictions.change_prediction()
    |> to_form()
  end
end
