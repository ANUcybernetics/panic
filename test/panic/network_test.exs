defmodule Panic.NetworkTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Engine.Network
  alias Panic.Models

  describe "CRUD actions" do
    # now if our action inputs are invalid when we think they should be valid, we will find out here
    property "accepts all valid input" do
      check all(input <- create_generator()) do
        assert %Ash.Changeset{valid?: true} =
                 Panic.Engine.changeset_to_create_network(
                   input.name,
                   input.description,
                   input.models,
                   authorize?: false
                 )
      end
    end

    # same as the above, but actually call the action. This tests the underlying action implementation
    # not just intial validation
    property "succeeds on all valid input" do
      check all(input <- create_generator()) do
        assert Panic.Engine.create_network!(
                 input.name,
                 input.description,
                 input.models,
                 authorize?: false
               )
      end
    end

    property "Network read action" do
      check all(input <- create_generator()) do
        network =
          Panic.Engine.create_network!(
            input.name,
            input.description,
            input.models,
            authorize?: false
          )

        assert network.id == Panic.Engine.get_network!(network.id).id
      end
    end

    property "Network set_state action" do
      check all(
              input <- create_generator(),
              state <- member_of([:starting, :running, :paused, :stopped])
            ) do
        network =
          Panic.Engine.create_network!(
            input.name,
            input.description,
            input.models,
            authorize?: false
          )

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

    test "read the created network back from the db" do
      %Network{id: network_id} = network_fixture()
      assert %Network{id: ^network_id} = Panic.Engine.get_network!(network_id)
    end

    test "create action with invalid data returns error changeset" do
      assert {:error, %Ash.Error.Invalid{}} =
               Panic.Engine.create_network("Good name", "Good description", [BadModule])
    end

    test "set_state action changes the network state to :starting" do
      network =
        network_fixture()
        |> Ash.Changeset.for_update(:set_state, %{state: :starting})
        |> Ash.update!()

      assert network.state == :starting
    end

    test "set_state code interface works" do
      network = Panic.Engine.set_state!(network_fixture(), :paused)
      assert network.state == :paused
    end

    # test "update_network/2 with valid data updates the network" do
    #   network = network_fixture()

    #   update_attrs = %{
    #     description: "some updated description",
    #     models: ["openai:text-davinci-003"],
    #     name: "some updated name"
    #   }

    #   assert {:ok, %Network{} = network} = Network.update_network(network, update_attrs)
    #   assert network.description == "some updated description"
    #   assert network.models == ["openai:text-davinci-003"]
    #   assert network.name == "some updated name"
    # end

    # test "update_network/2 with invalid data returns error changeset" do
    #   network = network_fixture()
    #   assert {:error, %Ecto.Changeset{}} = Network.update_network(network, @invalid_attrs)
    #   assert network == Network.get_network!(network.id)
    # end

    # test "delete_network/1 deletes the network" do
    #   network = network_fixture()
    #   assert {:ok, %Network{}} = Network.delete_network(network)
    #   assert_raise Ecto.NoResultsError, fn -> Network.get_network!(network.id) end
    # end
  end

  # # used to be in a separate module, but not necessary for now
  defp network_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          name: "My Network",
          description: "A super cool network",
          models: [
            # TODO change this to an actual model module once they exist
            Panic.Engine
          ]
        },
        attrs
      )

    Network
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!()
  end

  defp create_generator do
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
