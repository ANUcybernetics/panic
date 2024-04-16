defmodule Panic.NetworkTest do
  use Panic.DataCase

  describe "Panic.Topology.Network resource" do
    alias Panic.Topology.Network

    test "changeset for :create action with valid data creates a network" do
      valid_attrs = %{
        name: "My Network",
        description: "A super cool network",
        models: [
          # TODO change this to an actual model module once they exist
          Panic.Topology
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
          Panic.Topology
        ]
      }

      network =
        Panic.Topology.create_network!(
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
      assert %Network{id: ^network_id} = Panic.Topology.get_network!(network_id)
    end

    test "create action with invalid data returns error changeset" do
      assert {:error, %Ash.Error.Invalid{}} =
               Panic.Topology.create_network("Good name", "Good description", [BadModule])
    end

    test "set_state action changes the network state to :starting" do
      network = network_fixture()
      {:ok, network} = Panic.Topology.set_state(network.id, :starting)
      assert network.state == :starting
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
            Panic.Topology
          ]
        },
        attrs
      )

    Panic.Topology.create_network!(
      attrs.name,
      attrs.description,
      attrs.models
    )
  end
end
