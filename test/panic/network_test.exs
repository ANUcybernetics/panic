defmodule Panic.NetworkTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Engine.Network

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

    property "append_model action adds models in correct order" do
      user = Panic.Fixtures.user()

      check all(network <- Panic.Generators.network(user)) do
        model1 = Panic.Models.SDXL
        model2 = Panic.Models.BLIP2

        network =
          network
          |> Panic.Engine.append_model!(model1, actor: user)
          |> Panic.Engine.append_model!(model2, actor: user)

        assert [^model1, ^model2] = network.models
      end
    end

    test "model IO types in network can be validated with helper fn" do
      import Panic.Validations.ModelIOConnections
      user = Panic.Fixtures.user()
      network = Panic.Generators.network(user) |> pick()

      assert {:error, _} = network_runnable?(network.models)

      network = Panic.Engine.append_model!(network, Panic.Models.SDXL, actor: user)
      assert {:error, _} = network_runnable?(network.models)

      network = Panic.Engine.append_model!(network, Panic.Models.BLIP2, actor: user)
      assert :ok = network_runnable?(network.models)

      # the final time it should fail because the "loop connection" doesnt match
      network = Panic.Engine.append_model!(network, Panic.Models.SDXL, actor: user)
      assert {:error, _} = network_runnable?(network.models)
    end

    test "network_with_models generator creates network with valid models" do
      user = Panic.Fixtures.user()
      network = Panic.Generators.network_with_models(user) |> pick()
      assert [first_model | _] = network.models
      assert first_model.fetch!(:input_type) == :text
    end
  end

  defp input_for_create do
    Ash.Generator.action_input(Network, :create, %{
      description: StreamData.binary()
    })
  end
end
