defmodule Panic.NetworksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Networks` context.
  """

  import Panic.AccountsFixtures

  @doc """
  Generate a network.
  """
  def network_fixture(attrs \\ %{}) do
    user = user_fixture()

    {:ok, network} =
      Map.merge(
        %{
          description: "some description",
          models: ["model1", "model2"],
          name: "some name",
          user_id: user.id
        },
        attrs
      )
      |> Panic.Networks.create_network()

    network
  end
end
