defmodule PanicWeb.PredictionLive.Terminal do
  @moduledoc """
  The main Panic "input terminal".

  The form her is so simple (just a text input) that it doesn't do the usual
  changeset thing; it just grabs the input string and dispatches it straight to
  `Predictions.create_prediction_async/3`.

  """
  use PanicWeb, :live_view
  alias Panic.{Accounts, Predictions, Networks}

  @impl true
  def mount(_params, _session, socket) do
    missing_tokens = Accounts.missing_api_tokens(socket.assigns.current_user)

    if Enum.empty?(missing_tokens) do
      {:ok, socket}
    else
      {:ok, apply_action(socket, :tokens_missing, missing_tokens)}
    end
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    {:noreply, apply_action(socket, :new_network, network_id)}
  end

  @impl true
  def handle_event("start-run", %{"prediction" => %{"input" => ""}}, socket),
    do: {:noreply, socket}

  @impl true
  def handle_event("start-run", %{"prediction" => %{"input" => input}}, socket) do
    Predictions.create_prediction_async(input, socket.assigns.network, fn prediction ->
      Finitomata.transition(prediction.network.id, {:new_prediction, prediction})
    end)

    {:noreply, socket}
  end

  defp apply_action(socket, :tokens_missing, missing_tokens) do
    socket
    |> put_flash(:info, "#{Enum.join(missing_tokens, "/")} API tokens are required to run Panic!")
  end

  defp apply_action(socket, :new_network, network_id) do
    network = Networks.get_network!(network_id)
    ## empty and invalid, but we're only pulling out the input string anyway
    changeset = Predictions.change_prediction(%Predictions.Prediction{})

    assign(socket, network: network, form: to_form(changeset))
  end
end
