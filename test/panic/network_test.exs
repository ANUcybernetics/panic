defmodule Panic.NetworkTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Engine.Network
  alias Panic.Models

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

    property "Network read action" do
      check all(network <- Panic.Generators.network()) do
        assert network.id == Panic.Engine.get_network!(network.id).id
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

  describe "Panic.Engine.Network resource" do
    test "changeset for :create action with valid data creates a network" do
      valid_attrs = %{
        name: "My Network",
        description: "A super cool network",
        models: [
          # TODO change this to an actual model module once they exist
          Models.GPT4o,
          Models.SDXL,
          Models.LLaVA
        ]
      }

      network =
        Network
        |> Ash.Changeset.for_create(:create, valid_attrs)
        |> Ash.create!()

      assert network.name == valid_attrs.name
      assert network.description == valid_attrs.description
      assert network.models == valid_attrs.models
      assert network.state == :stopped
    end

    test "code interface for :create action with valid data creates a network" do
      valid_attrs = %{
        name: "My Network",
        description: "A super cool network",
        models: [
          # TODO change this to an actual model module once they exist
          Panic.Engine
        ]
      }

      network =
        Panic.Engine.create_network!(
          valid_attrs.name,
          valid_attrs.description,
          valid_attrs.models
        )

      assert network.name == valid_attrs.name
      assert network.description == valid_attrs.description
      assert network.models == valid_attrs.models
      assert network.state == :stopped
    end

    test "raise if there's no Network with a given id" do
      assert_raise Ash.Error.Invalid, fn -> Ash.get!(Network, 1234) end
    end

    test "create action with invalid data returns error changeset" do
      assert {:error, %Ash.Error.Invalid{}} =
               Panic.Engine.create_network("Good name", "Good description", [BadModule])
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
