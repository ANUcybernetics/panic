defmodule Panic.PredictionsTest do
  use Panic.DataCase, async: false

  alias Panic.Accounts
  alias Panic.Predictions
  alias Panic.Predictions.Prediction

  import Panic.{PredictionsFixtures, NetworksFixtures, AccountsFixtures}
  import Mock

  setup_with_mocks([
    {Panic.Platforms, [:passthrough],
     [
       api_call: fn model_id, input, _user ->
         {:ok, "#{model_id} API call result for input '#{input}'"}
       end
     ]}
  ]) do
    network = network_fixture()
    insert_api_tokens_from_env(network.user_id)

    {:ok, network: network, tokens: Accounts.get_api_token_map(network.user_id)}
  end

  describe "predictions" do
    @invalid_attrs %{input: nil, metadata: nil, model: nil, output: nil, run_index: nil}

    test "get_prediction!/1 returns the prediction with given id" do
      prediction = network_fixture() |> genesis_prediction_fixture()
      assert Predictions.get_prediction!(prediction.id) == prediction
    end

    test "update_prediction/2 with valid data updates the prediction" do
      prediction = network_fixture() |> genesis_prediction_fixture()

      update_attrs = %{
        input: "some updated input",
        metadata: %{},
        model: "some updated model",
        output: "some updated output",
        run_index: 43
      }

      assert {:ok, %Prediction{} = prediction} =
               Predictions.update_prediction(prediction, update_attrs)

      assert prediction.input == "some updated input"
      assert prediction.metadata == %{}
      assert prediction.model == "some updated model"
      assert prediction.output == "some updated output"
      assert prediction.run_index == 43
    end

    test "update_prediction/2 with invalid data returns error changeset" do
      prediction = network_fixture() |> genesis_prediction_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Predictions.update_prediction(prediction, @invalid_attrs)

      assert prediction == Predictions.get_prediction!(prediction.id)
    end

    test "delete_prediction/1 deletes the prediction" do
      prediction = network_fixture() |> genesis_prediction_fixture()
      assert {:ok, %Prediction{}} = Predictions.delete_prediction(prediction)
      assert_raise Ecto.NoResultsError, fn -> Predictions.get_prediction!(prediction.id) end
    end

    test "change_prediction/1 returns a prediction changeset" do
      prediction = network_fixture() |> genesis_prediction_fixture()
      assert %Ecto.Changeset{} = Predictions.change_prediction(prediction)
    end
  end

  describe "create genesis/next predictions (mocked platform API calls)" do
    test "create_prediction/2 works with valid params",
         %{network: network, tokens: tokens} do
      input = "Tell me a joke about potatoes."

      assert {:ok, %Prediction{output: output}} =
               Predictions.create_genesis_prediction(input, network, tokens)

      assert is_binary(output)
    end

    test "create_prediction/2 followed by create_next_prediction/2 works",
         %{network: network, tokens: tokens} do
      input = "Tell me a joke about potatoes."

      assert {:ok, %Prediction{run_index: 0} = genesis} =
               Predictions.create_genesis_prediction(input, network, tokens)

      assert is_binary(genesis.output)

      genesis_id = genesis.id

      assert {:ok, %Prediction{run_index: 1, genesis_id: ^genesis_id}} =
               Predictions.create_next_prediction(genesis, tokens)
    end
  end
end
