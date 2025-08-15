defmodule PanicWeb.NetworkLive.NetworkHelpers do
  @moduledoc """
  Helper functions for network validation and missing model handling.
  Centralizes logic for checking if networks have missing models and
  providing appropriate redirects or fallbacks.
  """

  use Phoenix.VerifiedRoutes,
    router: PanicWeb.Router,
    endpoint: PanicWeb.Endpoint

  alias Panic.Model
  alias Phoenix.LiveView

  @doc """
  Checks if a network has any missing models.
  Returns {:ok, models} if all models exist, or {:error, missing_ids} if any are missing.
  """
  def check_network_models(model_ids) do
    {existing, missing} =
      Enum.reduce(model_ids, {[], []}, fn id, {existing_acc, missing_acc} ->
        case Model.by_id(id) do
          nil -> {existing_acc, [id | missing_acc]}
          model -> {[model | existing_acc], missing_acc}
        end
      end)

    case missing do
      [] -> {:ok, Enum.reverse(existing)}
      missing_ids -> {:error, Enum.reverse(missing_ids)}
    end
  end

  @doc """
  Handles a network with missing models by redirecting to the network show page
  with an appropriate flash message. Used by pages that need a runnable network.
  """
  def handle_broken_network(socket, network, missing_ids) do
    message =
      "This network contains models that no longer exist: #{Enum.join(missing_ids, ", ")}. " <>
        "Please fix the network configuration."

    socket
    |> LiveView.put_flash(:error, message)
    |> LiveView.push_navigate(to: ~p"/networks/#{network}")
  end

  @doc """
  Returns a placeholder model struct for display purposes when a model is missing.
  This allows historical invocations to still be viewable.
  """
  def placeholder_model(model_id) do
    %{
      id: model_id,
      name: "Unknown Model (#{model_id})",
      platform: nil,
      input_type: :unknown,
      output_type: :unknown,
      path: nil,
      invoke: nil,
      description: "This model no longer exists in the system."
    }
  end

  @doc """
  Gets a model by ID, returning a placeholder if it doesn't exist.
  Useful for display components that need to show historical data.
  """
  def get_model_or_placeholder(model_id) do
    Model.by_id(model_id) || placeholder_model(model_id)
  end
end
