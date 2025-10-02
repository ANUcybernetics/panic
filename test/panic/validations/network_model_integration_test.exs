defmodule Panic.Validations.NetworkModelIntegrationTest do
  @moduledoc """
  Integration tests for network model validation.
  Uses dummy models to avoid API calls.
  """
  use Panic.DataCase, async: false

  alias Ash.Error.Invalid
  alias Panic.Fixtures

  describe "network model updates with validation" do
    test "successfully updates network with valid text->text cycle" do
      user = Fixtures.user()
      network = create_test_network(user, ["dummy-t2t"])

      # Update with valid text->text models
      changeset =
        Ash.Changeset.for_update(network, :update_models, %{models: ["dummy-t2t", "dummy-t2t"]}, actor: user)

      {:ok, updated} = Ash.update(changeset)

      assert updated.models == ["dummy-t2t", "dummy-t2t"]
    end

    test "rejects network update with invalid I/O chain" do
      user = Fixtures.user()
      network = create_test_network(user, ["dummy-t2t"])

      # Try to update with incompatible models
      # dummy-t2i outputs image, but dummy-t2t needs text input
      changeset =
        Ash.Changeset.for_update(network, :update_models, %{models: ["dummy-t2i", "dummy-t2t"]}, actor: user)

      result = Ash.update(changeset)

      assert {:error, %Invalid{}} = result
    end

    test "rejects network that doesn't form a cycle" do
      user = Fixtures.user()
      network = create_test_network(user, ["dummy-t2t"])

      # dummy-t2i outputs image, but first model needs text input
      # This doesn't form a valid cycle
      changeset =
        Ash.Changeset.for_update(network, :update_models, %{models: ["dummy-t2i", "dummy-i2i"]}, actor: user)

      result = Ash.update(changeset)

      assert {:error, %Invalid{}} = result
    end

    test "rejects empty network" do
      user = Fixtures.user()
      network = create_test_network(user, ["dummy-t2t"])

      # Try to clear network (should fail - empty network not allowed)
      changeset = Ash.Changeset.for_update(network, :update_models, %{models: []}, actor: user)
      result = Ash.update(changeset)

      assert {:error, %Invalid{}} = result
    end

    test "maintains model order in network" do
      user = Fixtures.user()
      network = create_test_network(user, ["dummy-t2t"])
      models = ["dummy-t2t", "dummy-t2t", "dummy-t2t"]

      changeset =
        Ash.Changeset.for_update(network, :update_models, %{models: models}, actor: user)

      {:ok, updated} = Ash.update(changeset)

      assert updated.models == models
    end
  end

  describe "complex network scenarios" do
    test "handles multi-type cycle correctly" do
      user = Fixtures.user()
      network = create_test_network(user, ["dummy-t2t"])

      # Create a valid text -> image -> text cycle
      changeset =
        Ash.Changeset.for_update(network, :update_models, %{models: ["dummy-t2i", "dummy-i2t"]}, actor: user)

      {:ok, updated} = Ash.update(changeset)

      assert updated.models == ["dummy-t2i", "dummy-i2t"]
    end

    test "validates identical model repetition" do
      user = Fixtures.user()
      network = create_test_network(user, ["dummy-t2t"])

      # Same model repeated (valid for text->text models)
      changeset =
        Ash.Changeset.for_update(
          network,
          :update_models,
          %{models: ["dummy-t2t", "dummy-t2t", "dummy-t2t"]},
          actor: user
        )

      {:ok, updated} = Ash.update(changeset)

      assert updated.models == ["dummy-t2t", "dummy-t2t", "dummy-t2t"]
    end
  end

  # Helper to create a test network
  defp create_test_network(user, initial_models) do
    # Networks start with empty models, but validation prevents empty networks
    # So we need to handle this carefully
    network =
      Panic.Engine.create_network!(
        "Test Network",
        "Test network for validation tests",
        actor: user
      )

    # Only update if we have models to set
    if initial_models == [] do
      network
    else
      changeset =
        Ash.Changeset.for_update(network, :update_models, %{models: initial_models}, actor: user)

      result = Ash.update(changeset)

      case result do
        {:ok, updated} -> updated
        {:error, error} -> raise error
      end
    end
  end
end
