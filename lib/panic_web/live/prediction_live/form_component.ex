defmodule PanicWeb.PredictionLive.FormComponent do
  use PanicWeb, :live_component

  alias Panic.Predictions

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Start a new Panic! run by creating a new AI prediction.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="prediction-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:input]} type="text" label="Input" />
        <:actions>
          <.button phx-disable-with="Creating...">Create Prediction</.button>
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
    prediction_params = add_user_id(prediction_params, socket)

    changeset =
      socket.assigns.prediction
      |> Predictions.change_prediction(prediction_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"prediction" => prediction_params}, socket) do
    prediction_params = add_user_id(prediction_params, socket)
    save_prediction(socket, socket.assigns.action, prediction_params)
  end

  defp save_prediction(socket, :new, prediction_params) do
    case Predictions.create_prediction(prediction_params, :genesis, socket.assigns.network) do
      {:ok, _prediction} ->
        {:noreply,
         socket
         |> put_flash(:info, "Prediction created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  ## these functions are all to deal with the "cast error: mixed atom and string
  ## keys" problem. If I find a nicer way to do this I'll change it
  defp to_atom(x) when is_binary(x), do: String.to_atom(x)
  defp to_atom(x) when is_atom(x), do: x

  defp add_user_id(params, socket) do
    for {k, v} <- Map.put(params, :user_id, socket.assigns.user.id), into: %{} do
      {to_atom(k), v}
    end
  end
end
