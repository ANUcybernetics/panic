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
          description: "a test network (but the models are real)",
          models: ["openai:text-davinci-003", "openai:text-ada-001"],
          name: "My Awesome Network",
          user_id: user.id
        },
        attrs
      )
      |> Panic.Networks.create_network()

    network
  end
end
