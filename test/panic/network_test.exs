defmodule Panic.NetworkTest do
  use Panic.DataCase
  use ExUnitProperties

  import Panic.Validations.ModelIOConnections

  alias Panic.Accounts.User
  alias Panic.Engine.Network

  describe "Network CRUD operations" do
    test "lockout_seconds defaults to 30" do
      user = Ash.Generator.seed!(User)

      network =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network", description: "Test"}, actor: user)
        |> Ash.create!()

      assert network.lockout_seconds == 30
    end

    test "lockout_seconds can be set during creation" do
      user = Ash.Generator.seed!(User)

      network =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network", description: "Test", lockout_seconds: 60},
          actor: user
        )
        |> Ash.create!()

      assert network.lockout_seconds == 60
    end

    test "lockout_seconds can be updated" do
      user = Ash.Generator.seed!(User)

      network =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network", description: "Test"}, actor: user)
        |> Ash.create!()

      updated_network =
        network
        |> Ash.Changeset.for_update(:update, %{lockout_seconds: 120}, actor: user)
        |> Ash.update!()

      assert updated_network.lockout_seconds == 120
    end

    # now if our action inputs are invalid when we think they should be valid, we will find out here
    property "create changeset accepts valid input without actor" do
      user = Panic.Fixtures.user()

      check all(input <- input_for_create()) do
        assert %Ash.Changeset{valid?: true} =
                 Panic.Engine.changeset_to_create_network(
                   input.name,
                   input.description,
                   actor: user
                 )
      end
    end

    property "create changeset accepts valid input with actor" do
      user = Panic.Generators.user()

      check all(input <- input_for_create()) do
        assert %Ash.Changeset{valid?: true} =
                 Panic.Engine.changeset_to_create_network(
                   input.name,
                   input.description,
                   actor: user,
                   authorize?: false
                 )
      end
    end

    property "create action succeeds with valid input" do
      user = Panic.Fixtures.user()

      check all(input <- input_for_create()) do
        Network
        |> Ash.Changeset.for_create(:create, input, actor: user)
        |> Ash.create!()
      end
    end

    property "create action via code interface succeeds with valid input" do
      user = Panic.Fixtures.user()

      check all(input <- input_for_create()) do
        {:ok, network} =
          Panic.Engine.create_network(
            input.name,
            input.description,
            actor: user
          )

        assert network.name == input.name
        # FIXME there might be an issue here with "" vs nil?
        # assert network.description == input.description
        assert network.models == []
      end
    end

    # TODO what's the best way with property testing to test that it gives the right invalid changeset on invalid input?

    property "read action retrieves correct network, raises on invalid ID, and forbidden with no actor" do
      user = Panic.Fixtures.user()

      check all(network <- Panic.Generators.network(user)) do
        assert network.id == Ash.get!(Network, network.id, actor: user).id
        # there shouldn't ever be a negative ID in the db, so this should always raise
        assert_raise Ash.Error.Invalid, fn -> Ash.get!(Network, -1, actor: user) end
        assert_raise Ash.Error.Forbidden, fn -> Ash.get!(Network, -1) end
      end
    end

    property ":update action updates name & description" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network(user),
              updated_name <- string(:utf8, min_length: 1),
              updated_description <- string(:utf8, min_length: 1)
            ) do
        network =
          network
          |> Ash.Changeset.for_update(
            :update,
            %{name: updated_name, description: updated_description},
            actor: user
          )
          |> Ash.update!()

        assert network.name == updated_name
        assert network.description == updated_description
      end
    end

    test "update_models validates things correctly" do
      user = Panic.Fixtures.user()
      network = user |> Panic.Generators.network() |> pick()

      # Valid chain: text -> image -> text
      valid_model_ids = ["stable-diffusion", "bunny-phi-2-siglip"]
      assert {:ok, _} = Panic.Engine.update_models(network, valid_model_ids, actor: user)

      # Invalid chain: image -> text, then text -> image (starts with image input, not text)
      invalid_model_ids = ["bunny-phi-2-siglip", "stable-diffusion"]
      assert {:error, _} = Panic.Engine.update_models(network, invalid_model_ids, actor: user)
    end

    property "network_with_dummy_models generator creates network with valid models" do
      user = Panic.Fixtures.user()

      check all(network <- Panic.Generators.network_with_dummy_models(user)) do
        assert :ok = network_runnable?(network.models)
      end
    end
  end

  defp input_for_create do
    Ash.Generator.action_input(Network, :create, %{
      description: StreamData.binary()
    })
  end
end
