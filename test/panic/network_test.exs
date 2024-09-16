defmodule Panic.NetworkTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Engine.Network
  # for network_runnable?
  import Panic.Validations.ModelIOConnections

  describe "Network CRUD operations" do
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
        assert network.state == :stopped
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

    property "set_state action updates network state correctly" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network(user),
              state <- member_of([:starting, :running, :paused, :stopped])
            ) do
        network = Panic.Engine.set_state!(network, state, actor: user)
        assert network.state == state
      end
    end

    test "update_models validates things correctly" do
      user = Panic.Fixtures.user()
      network = Panic.Generators.network(user) |> pick()

      valid_model_ids = ["sdxl", "blip-2"]
      assert {:ok, _} = Panic.Engine.update_models(network, valid_model_ids, actor: user)

      invalid_model_ids = ["sdxl", "sdxl"]
      assert {:error, _} = Panic.Engine.update_models(network, invalid_model_ids, actor: user)
    end

    property "network_with_models generator creates network with valid models" do
      user = Panic.Fixtures.user()

      check all(network <- Panic.Generators.network_with_models(user)) do
        assert :ok = network_runnable?(network.models)
      end
    end

    @tag skip: "requires API keys"
    property "supports :start_run action" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              invocation <- Panic.Generators.invocation(network)
            ) do
        Panic.Engine.Network
        |> Ash.ActionInput.for_action(:start_run, %{first_invocation: invocation}, actor: user)
        |> Ash.run_action!()
      end
    end
  end

  defp input_for_create do
    Ash.Generator.action_input(Network, :create, %{
      description: StreamData.binary()
    })
  end
end
