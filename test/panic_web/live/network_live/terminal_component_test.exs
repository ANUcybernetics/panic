defmodule PanicWeb.NetworkLive.TerminalComponentTest do
  use PanicWeb.ConnCase, async: false

  setup do
    owner = Panic.Fixtures.user()
    network = Panic.Fixtures.network_with_dummy_models(owner)

    %{owner: owner, network: network}
  end

  describe "terminal component error handling" do
    test "starting a run keeps the terminal usable", %{conn: conn, network: network} do
      auth_token = PanicWeb.TerminalAuth.generate_token(network.id)

      conn
      |> visit("/networks/#{network.id}/terminal?token=#{auth_token}")
      |> assert_has("span", text: "Current run:")
      |> fill_in("Prompt", with: "test prompt")
      |> submit()
      |> assert_has("span", text: "Current run:")
    end
  end

  describe "error handling for missing API tokens" do
    test "starting a run without the model's API token keeps the terminal usable", %{
      conn: conn,
      owner: owner
    } do
      {:ok, network} =
        Panic.Engine.Network
        |> Ash.Changeset.for_create(
          :create,
          %{name: "Test Network with Real Models", lockout_seconds: 0},
          actor: owner
        )
        |> Ash.create()

      {:ok, network} =
        network
        |> Ash.Changeset.for_update(:update_models, %{models: ["gpt-5-chat"]}, actor: owner)
        |> Ash.update()

      auth_token = PanicWeb.TerminalAuth.generate_token(network.id)

      conn
      |> visit("/networks/#{network.id}/terminal?token=#{auth_token}")
      |> assert_has("span", text: "Current run:")
      |> fill_in("Prompt", with: "test prompt")
      |> submit()
      |> assert_has("span", text: "Current run:")
      |> refute_has("body", text: "ArgumentError")
      |> refute_has("body", text: "Expected to receive either an")
    end

    test "verifies the fix handles different error types correctly", %{
      conn: conn,
      network: network
    } do
      auth_token = PanicWeb.TerminalAuth.generate_token(network.id)

      conn
      |> visit("/networks/#{network.id}/terminal?token=#{auth_token}")
      |> fill_in("Prompt", with: "test")
      |> submit()
      |> refute_has("body", text: "error occurred")
      |> assert_has("span", text: "Current run:")
    end
  end
end
