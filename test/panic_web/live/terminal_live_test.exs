defmodule PanicWeb.TerminalLiveTest do
  use PanicWeb.ConnCase, async: true
  use ExUnitProperties
  # import Phoenix.LiveViewTest

  describe "user IS logged in" do
    @describetag skip: "requires API keys"
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "and can create a new invocation in the terminal", %{conn: conn, user: user} do
      # TODO currently I can't get PhoenixTest to fill out the LiveSelect yet, so fake it for now
      network = user |> Panic.Generators.network_with_models() |> pick()

      conn
      |> visit("/networks/#{network.id}/terminal")
      |> fill_in("Prompt...", with: "a sheep on the grass")
      |> submit()
    end
  end
end
