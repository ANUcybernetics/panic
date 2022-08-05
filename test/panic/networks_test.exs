defmodule Panic.NetworksTest do
  use Panic.DataCase

  alias Panic.Networks

  describe "networks" do
    alias Panic.Networks.Network

    import Panic.NetworksFixtures

    @invalid_attrs %{loop: nil, models: nil, name: nil}

    test "list_networks/0 returns all networks" do
      network = network_fixture()
      assert Networks.list_networks() == [network]
    end

    test "get_network!/1 returns the network with given id" do
      network = network_fixture()
      assert Networks.get_network!(network.id) == network
    end

    test "create_network/1 with valid data creates a network" do
      valid_attrs = %{loop: true, models: [], name: "some name"}

      assert {:ok, %Network{} = network} = Networks.create_network(valid_attrs)
      assert network.loop == true
      assert network.models == []
      assert network.name == "some name"
    end

    test "create_network/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Networks.create_network(@invalid_attrs)
    end

    test "update_network/2 with valid data updates the network" do
      network = network_fixture()
      update_attrs = %{loop: false, models: [], name: "some updated name"}

      assert {:ok, %Network{} = network} = Networks.update_network(network, update_attrs)
      assert network.loop == false
      assert network.models == []
      assert network.name == "some updated name"
    end

    test "update_network/2 with invalid data returns error changeset" do
      network = network_fixture()
      assert {:error, %Ecto.Changeset{}} = Networks.update_network(network, @invalid_attrs)
      assert network == Networks.get_network!(network.id)
    end

    test "delete_network/1 deletes the network" do
      network = network_fixture()
      assert {:ok, %Network{}} = Networks.delete_network(network)
      assert_raise Ecto.NoResultsError, fn -> Networks.get_network!(network.id) end
    end

    test "change_network/1 returns a network changeset" do
      network = network_fixture()
      assert %Ecto.Changeset{} = Networks.change_network(network)
    end
  end
end
