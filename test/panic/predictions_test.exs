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
    alias Panic.Predictions.Prediction

    import Panic.PredictionsFixtures

    @invalid_attrs %{input: nil, output: nil, metadata: nil, model: nil, run_index: nil}

    test "list_predictions/0 returns all predictions" do
      prediction = prediction_fixture()
      assert Predictions.list_predictions() == [prediction]
    end

    test "get_prediction!/1 returns the prediction with given id" do
      prediction = prediction_fixture()
      assert Predictions.get_prediction!(prediction.id) == prediction
    end

    test "create_prediction/1 with valid data creates a prediction" do
      valid_attrs = %{input: "some input", output: "some output", metadata: %{}, model: "some model", run_index: 42}

      assert {:ok, %Prediction{} = prediction} = Predictions.create_prediction(valid_attrs)
      assert prediction.input == "some input"
      assert prediction.output == "some output"
      assert prediction.metadata == %{}
      assert prediction.model == "some model"
      assert prediction.run_index == 42
    end

    test "create_prediction/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Predictions.create_prediction(@invalid_attrs)
    end

    test "update_prediction/2 with valid data updates the prediction" do
      prediction = prediction_fixture()
      update_attrs = %{input: "some updated input", output: "some updated output", metadata: %{}, model: "some updated model", run_index: 43}

      assert {:ok, %Prediction{} = prediction} = Predictions.update_prediction(prediction, update_attrs)
      assert prediction.input == "some updated input"
      assert prediction.output == "some updated output"
      assert prediction.metadata == %{}
      assert prediction.model == "some updated model"
      assert prediction.run_index == 43
    end

    test "update_prediction/2 with invalid data returns error changeset" do
      prediction = prediction_fixture()
      assert {:error, %Ecto.Changeset{}} = Predictions.update_prediction(prediction, @invalid_attrs)
      assert prediction == Predictions.get_prediction!(prediction.id)
    end

    test "delete_prediction/1 deletes the prediction" do
      prediction = prediction_fixture()
      assert {:ok, %Prediction{}} = Predictions.delete_prediction(prediction)
      assert_raise Ecto.NoResultsError, fn -> Predictions.get_prediction!(prediction.id) end
    end

    test "change_prediction/1 returns a prediction changeset" do
      prediction = prediction_fixture()
      assert %Ecto.Changeset{} = Predictions.change_prediction(prediction)
    end
  end
end
