defmodule Panic.PredictionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Predictions` context.
  """

  import Panic.NetworksFixtures
  alias Panic.Predictions

  @doc """
  Generate a (genesis) prediction.

  This is expecting a map of fake data; it won't be a genesis prediction, and
  as a "next" prediction there won't be any preceeding ones.

  """
  def prediction_fixture(attrs \\ %{}) do
    network = network_fixture()
    Panic.AccountsFixtures.insert_api_tokens_from_env(network.user_id)
    tokens = Panic.Accounts.get_api_token_map(network.user_id)

    {:ok, prediction} = Predictions.create_genesis_prediction("some input", network, tokens)

    prediction
  end
end
