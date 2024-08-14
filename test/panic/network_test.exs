defmodule Panic.NetworkTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Engine.Network

  describe "CRUD actions" do
    # now if our action inputs are invalid when we think they should be valid, we will find out here
    property "accepts all valid input" do
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

    property "accepts all valid input (with an actor)" do
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

    property "succeeds on all valid input" do
      user = Panic.Fixtures.user()

      check all(input <- input_for_create()) do
        Network
        |> Ash.Changeset.for_create(:create, input, actor: user)
        |> Ash.create!()
      end
    end

    property "succeeds on all valid input (code interface version)" do
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

    property "Network read action" do
      user = Panic.Fixtures.user()

      check all(network <- Panic.Generators.network(user)) do
        assert network.id == Panic.Engine.get_network!(network.id).id
        # there shouldn't ever be a negative ID in the db, so this should always raise
        assert_raise Ash.Error.Invalid, fn -> Ash.get!(Network, -1) end
      end
    end

    property "Network set_state action" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network(user),
              state <- member_of([:starting, :running, :paused, :stopped])
            ) do
        network = Panic.Engine.set_state!(network.id, state)
        assert network.state == state
      end
    end

    property "can append models with correct modality" do
      user = Panic.Fixtures.user()

      check all(network <- Panic.Generators.network(user)) do
        model1 = Panic.Models.SDXL
        model2 = Panic.Models.BLIP2

        network =
          network
          |> Panic.Engine.append_model!(model1)
          |> Panic.Engine.append_model!(model2)

        assert [^model1, ^model2] = network.models
      end
    end

    test "network_with_models generator" do
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
