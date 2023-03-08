defmodule Panic.PredictionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Predictions` context.
  """

  import Panic.NetworksFixtures
  alias Panic.Predictions

  @doc """
  Generate a (genesis) prediction.

  Unless `Panic.Platforms.api_call/3` is mocked in the calling context, this
  will make a real platform API call.

  """
  def genesis_prediction_fixture() do
    network = network_fixture()
    Panic.AccountsFixtures.insert_api_tokens_from_env(network.user_id)
    tokens = Panic.Accounts.get_api_token_map(network.user_id)

    {:ok, prediction} = Predictions.create_genesis_prediction("some input", network, tokens)

    prediction
  end
end
