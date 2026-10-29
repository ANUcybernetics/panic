defmodule PanicWeb.NetworkLive.TerminalComponentTest do
  use PanicWeb.ConnCase, async: false

  setup do
    owner = Panic.Fixtures.user()
    network = Panic.Fixtures.network_with_dummy_models(owner)

    %{owner: owner, network: network}
  end

  describe "terminal component error handling" do
    test "starting a run keeps the terminal usable", %{conn: conn, network: network} do
      auth_token = anon_token(network)

      conn
      |> visit("/networks/#{network.id}/terminal?token=#{auth_token}")
      |> assert_has("span", text: "Current run:")
      |> fill_in("Prompt", with: "test prompt")
      |> submit()
      |> assert_has("span", text: "Current run:")
    end
  end

  describe "start-run errors" do
    test "a network with no models says so", %{conn: conn, owner: owner} do
      network = Panic.Fixtures.network(owner)
      auth_token = anon_token(network)

      conn
      |> visit("/networks/#{network.id}/terminal?token=#{auth_token}")
      |> fill_in("Prompt", with: "test prompt")
      |> submit()
      |> assert_has("[role=alert]", text: "No models in network")
    end

    test "a second prompt during the lockout asks the visitor to wait", %{
      conn: conn,
      network: network
    } do
      auth_token = anon_token(network)

      conn
      |> visit("/networks/#{network.id}/terminal?token=#{auth_token}")
      |> fill_in("Prompt", with: "first prompt")
      |> submit()
      |> fill_in("Prompt", with: "second prompt")
      |> submit()
      |> assert_has("[role=alert]", text: "Please wait before starting a new run")
    end
  end

  describe "error handling for missing platform keys" do
    test "starting a run without the model's platform key says so", %{
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

      auth_token = anon_token(network)

      conn
      |> visit("/networks/#{network.id}/terminal?token=#{auth_token}")
      |> assert_has("span", text: "Current run:")
      |> fill_in("Prompt", with: "test prompt")
      |> submit()
      |> assert_has("span", text: "Current run:")
      |> assert_has("[role=alert]", text: "No API key set for OpenAI")
      |> refute_has("body", text: "ArgumentError")
    end

    test "verifies the fix handles different error types correctly", %{
      conn: conn,
      network: network
    } do
      auth_token = anon_token(network)

      conn
      |> visit("/networks/#{network.id}/terminal?token=#{auth_token}")
      |> fill_in("Prompt", with: "test")
      |> submit()
      |> refute_has("body", text: "error occurred")
      |> assert_has("span", text: "Current run:")
    end
  end

  # opens the network's anonymous terminal, so these tests can visit it without signing in
  defp anon_token(network) do
    Panic.Engine.update_network!(network, %{anon_terminal_minutes: 10}, authorize?: false)
    PanicWeb.TerminalAuth.token(network.id)
  end
end
