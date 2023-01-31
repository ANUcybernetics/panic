defmodule Panic.NetworksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Networks` context.
  """

  @doc """
  Generate a network.
  """
  def network_fixture(attrs \\ %{}) do
    {:ok, network} =
      attrs
      |> Enum.into(%{
        description: "some description",
        models: ["option1", "option2"],
        name: "some name"
      })
      |> Panic.Networks.create_network()

    network
  end
end
