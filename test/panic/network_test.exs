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

    test "raise if there's no Network with a given id" do
      assert_raise Ash.Error.Invalid, fn -> Ash.get!(Network, 1234) end
    end

    # test "create action works with good inlist_networks/1 returns all networks" do
    #   network = network_fixture()
    #   user = Panic.Accounts.get_user!(network.user_id)
    #   assert Network.list_networks(user) == [network]
    # end

    # test "get_network!/1 returns the network with given id" do
    #   network = network_fixture()
    #   assert Network.get_network!(network.id) == network
    # end

    # test "create_network/1 with invalid data returns error changeset" do
    #   assert {:error, %Ecto.Changeset{}} = Network.create_network(@invalid_attrs)
    # end

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

    # test "change_network/1 returns a network changeset" do
    #   network = network_fixture()
    #   assert %Ecto.Changeset{} = Network.change_network(network)
    # end
  end

  # # used to be in a separate module, but not necessary for now
  # defp network_fixture(attrs \\ %{}) do
  #   {:ok, network} =
  #     Map.merge(
  #       %{
  #         description: "a test network (but the models are real)",
  #         models: ["openai:text-davinci-003", "openai:text-ada-001"],
  #         name: "My Awesome Network",
  #         user_id: user.id
  #       },
  #       attrs
  #     )
  #     |> Panic.Networks.create_network()

  #   network
  # end
end
