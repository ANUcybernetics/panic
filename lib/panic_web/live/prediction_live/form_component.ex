defmodule PanicWeb.PredictionLive.FormComponent do
  use PanicWeb, :live_component

  alias Panic.Predictions

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage prediction records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="prediction-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:input]} type="text" label="Input" />
        <.input field={@form[:metadata]} type="text" label="Metadata" />
        <.input field={@form[:model]} type="text" label="Model" />
        <.input field={@form[:output]} type="text" label="Output" />
        <.input field={@form[:run_index]} type="number" label="Run index" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Prediction</.button>
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
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"prediction" => prediction_params}, socket) do
    changeset =
      socket.assigns.prediction
      |> Predictions.change_prediction(prediction_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"prediction" => prediction_params}, socket) do
    save_prediction(socket, socket.assigns.action, prediction_params)
  end

  defp save_prediction(socket, :edit, prediction_params) do
    case Predictions.update_prediction(socket.assigns.prediction, prediction_params) do
      {:ok, prediction} ->
        notify_parent({:saved, prediction})

        {:noreply,
         socket
         |> put_flash(:info, "Prediction updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_prediction(socket, :new, prediction_params) do
    case Predictions.create_prediction(prediction_params) do
      {:ok, prediction} ->
        notify_parent({:saved, prediction})

        {:noreply,
         socket
         |> put_flash(:info, "Prediction created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
