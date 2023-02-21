defmodule PanicWeb.PredictionLive.TerminalComponent do
  use PanicWeb, :live_component

  alias Panic.Predictions

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="prediction-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="start-run"
      >
        <.input field={@form[:input]} type="text" label="Input" />
        <:actions>
          <.button
            class="w-64 h-64 mx-auto rounded-full text-4xl text-white bg-red-700"
            phx-disable-with="Panicking..."
          >
            Panic
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{prediction: prediction} = assigns, socket) do
    changeset = Predictions.change_prediction(prediction)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"prediction" => prediction_params}, socket) do
    changeset =
      socket.assigns.prediction
      |> Predictions.change_prediction(prediction_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("start-run", %{"prediction" => prediction_params}, socket) do
    save_prediction(socket, prediction_params)
  end

  defp save_prediction(socket, %{"input" => input}) do
    case Predictions.create_prediction(input, socket.assigns.network) do
      {:ok, _prediction} ->
        {:noreply,
         socket
         |> put_flash(:info, "Prediction created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
