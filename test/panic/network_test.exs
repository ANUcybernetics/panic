defmodule Panic.NetworkTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Engine.Network

  describe "CRUD actions" do
    # now if our action inputs are invalid when we think they should be valid, we will find out here
    property "accepts all valid input" do
      check all(input <- input_for_create()) do
        assert %Ash.Changeset{valid?: true} =
                 Panic.Engine.changeset_to_create_network(
                   input.name,
                   input.description,
                   input.models,
                   authorize?: false
                 )
      end
    end

    property "succeeds on all valid input" do
      check all(input <- input_for_create()) do
        Network
        |> Ash.Changeset.for_create(:create, input)
        |> Ash.create!()
      end
    end

    property "succeeds on all valid input (code interface version)" do
      check all(input <- input_for_create()) do
        {:ok, network} =
          Panic.Engine.create_network(
            input.name,
            input.description,
            input.models,
            authorize?: false
          )

        assert network.name == input.name
        # FIXME there might be an issue here with "" vs nil?
        # assert network.description == input.description
        assert network.models == input.models
        assert network.state == :stopped
      end
    end

    # TODO what's the best way with property testing to test that it gives the right invalid changeset on invalid input?

    property "Network read action" do
      check all(network <- Panic.Generators.network()) do
        assert network.id == Panic.Engine.get_network!(network.id).id
        # there shouldn't ever be a negative ID in the db, so this should always raise
        assert_raise Ash.Error.Invalid, fn -> Ash.get!(Network, -1) end
      end
    end

    property "Network set_state action" do
      check all(
              network <- Panic.Generators.network(),
              state <- member_of([:starting, :running, :paused, :stopped])
            ) do
        network = Panic.Engine.set_state!(network.id, state)
        assert network.state == state
      end
    end
  end

  defp input_for_create do
    Ash.Generator.action_input(Network, :create, %{
      models:
        list_of(
          StreamData.member_of([
            Panic.Models.SDXL,
            Panic.Models.BLIP2,
            Panic.Models.GPT4o
          ])
        ),
      description: StreamData.binary()
    })
  end
end
