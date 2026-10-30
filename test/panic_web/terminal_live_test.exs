defmodule PanicWeb.TerminalLiveTest do
  @moduledoc """
  The terminal at `/networks/:id/terminal`, and the anonymous terminal: the
  QR code on an installation's first screen that lets anyone at the installation
  prompt the network, without signing in, for the network's
  `anon_terminal_minutes` (see `PanicWeb.TerminalAuth`).
  """
  use PanicWeb.ConnCase, async: false
  use Repatch.ExUnit

  import Panic.EngineHelpers
  import Phoenix.LiveViewTest

  alias Panic.Engine
  alias Panic.Fixtures
  alias Panic.Platforms.Dummy
  alias Panic.Watcher.Installation
  alias PanicWeb.TerminalAuth

  @moduletag :capture_log

  setup do
    Panic.ExternalAPIPatches.setup()
    :ok
  end

  defp anon_network(user, minutes \\ 10) do
    user
    |> Fixtures.network_with_dummy_models()
    |> Engine.update_network!(%{anon_terminal_minutes: minutes, lockout_seconds: 0}, actor: user)
  end

  defp network_without_anon_terminal(user) do
    user
    |> Fixtures.network_with_dummy_models()
    |> Engine.update_network!(%{anon_terminal_minutes: nil}, actor: user)
  end

  defp minutes_ago(minutes), do: System.system_time(:second) - minutes * 60

  defp expired_path(network), do: ~p"/networks/#{network}/terminal/expired"

  describe "signed-in users" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "can start a run without a token", %{conn: conn, user: user} do
      network = Fixtures.network_with_dummy_models(user)

      conn
      |> visit(~p"/networks/#{network}/terminal")
      |> fill_in("Prompt", with: "a sheep on the grass")
      |> submit()
      |> assert_has("span", text: "a sheep on the grass")
      |> refute_has("#terminal-expiry")
    end

    test "don't need the anonymous terminal turned on, or a valid token", %{
      conn: conn,
      user: user
    } do
      network = Fixtures.network_with_dummy_models(user)

      conn
      |> visit(~p"/networks/#{network}/terminal?token=invalid")
      |> assert_has(".terminal-container", text: "Current run:")
    end
  end

  describe "anonymous users with a token from the QR code" do
    setup do
      {:ok, network: anon_network(Fixtures.user())}
    end

    test "can start a run, which acts as the network's owner", %{conn: conn, network: network} do
      conn
      |> visit(~p"/networks/#{network}/terminal?token=#{TerminalAuth.token(network.id)}")
      |> fill_in("Prompt", with: "a cat on a mat")
      |> submit()
      |> assert_has("span", text: "a cat on a mat")

      assert %{current_run_number: run} = Engine.get_network!(network.id, authorize?: false)
      assert Engine.get_invocation!(run, authorize?: false).input == "a cat on a mat"
    end

    test "are subject to the network's lockout", %{conn: conn, network: network} do
      network = Engine.update_network!(network, %{lockout_seconds: 600}, authorize?: false)
      Engine.start_run!(network, "the first run", authorize?: false)

      conn
      |> visit(~p"/networks/#{network}/terminal?token=#{TerminalAuth.token(network.id)}")
      |> fill_in("Prompt", with: "too soon")
      |> submit()
      |> assert_has("[role=alert]", text: "Please wait before starting a new run")
    end

    test "can find out what PANIC! is without closing the terminal", %{
      conn: conn,
      network: network
    } do
      {:ok, view, _html} =
        live(conn, ~p"/networks/#{network}/terminal?token=#{TerminalAuth.token(network.id)}")

      assert has_element?(view, ~s(#terminal-about[href="/about"][target="_blank"]))
    end

    test "see when the terminal closes", %{conn: conn, network: network} do
      token = TerminalAuth.token(network.id, minutes_ago(4))
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}/terminal?token=#{token}")

      expires_at = (minutes_ago(4) + 10 * 60) |> DateTime.from_unix!() |> DateTime.to_iso8601()
      assert has_element?(view, ~s(#terminal-expiry-countdown[data-target-time="#{expires_at}"]))
    end

    test "are sent to the expired page when the terminal closes", %{conn: conn, network: network} do
      # issued so it has a second left
      token = TerminalAuth.token(network.id, minutes_ago(10) + 1)
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}/terminal?token=#{token}")

      assert_redirect(view, expired_path(network), 3000)
    end
  end

  describe "the run summary" do
    setup %{conn: conn} do
      # each call reports a priced usage: US$0.03 and 1.0 Wh
      Repatch.patch(Dummy, :invoke, fn model, input, token ->
        {:ok, output, _usage} = Repatch.real(Dummy.invoke(model, input, token))
        {:ok, output, %{"platform" => "replicate", "path" => "krea/krea-3"}}
      end)

      %{conn: signed_in, user: user} = PanicWeb.Helpers.create_and_sign_in_user(%{conn: conn})

      network =
        user
        |> anon_network()
        |> Engine.update_models!(["dummy-t2i", "dummy-i2t"], actor: user)

      {:ok, signed_in: signed_in, user: user, network: network}
    end

    defp start_and_run(network, user, invocations) do
      Engine.start_run!(network, "a cat on a mat", actor: user)
      for _ <- 1..invocations, do: run_next_invocation()
    end

    test "shows a signed-in user the run so far, cost included", %{
      signed_in: conn,
      user: user,
      network: network
    } do
      start_and_run(network, user, 2)

      {:ok, view, _html} = live(conn, ~p"/networks/#{network}/terminal")

      assert has_element?(view, "#run-stats-sequence", "2")
      assert has_element?(view, "#run-summary-image[src^='https://dummy-images.test/']")
      assert has_element?(view, "#run-summary-text", "DUMMY_CAPTION")
      assert has_element?(view, "#run-stats-energy", "2.0 Wh")
      assert has_element?(view, "#run-stats-cost", "US$0.06")
      assert has_element?(view, "#run-stats-model", "Dummy Text-to-Image")
      assert has_element?(view, "#run-stats-elapsed", "under a minute")
    end

    test "keeps up as the run goes", %{signed_in: conn, user: user, network: network} do
      start_and_run(network, user, 1)
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}/terminal")
      refute has_element?(view, "#run-summary-text")

      run_next_invocation()

      assert has_element?(view, "#run-summary-text", "DUMMY_CAPTION")
      assert has_element?(view, "#run-stats-energy", "2.0 Wh")
    end

    test "shows anonymous users the energy but not the cost", %{
      conn: conn,
      user: user,
      network: network
    } do
      start_and_run(network, user, 2)

      {:ok, view, _html} =
        live(conn, ~p"/networks/#{network}/terminal?token=#{TerminalAuth.token(network.id)}")

      assert has_element?(view, "#run-stats-energy", "2.0 Wh")
      refute has_element?(view, "#run-stats-cost")
    end

    test "appears when a run starts", %{conn: conn, network: network} do
      {:ok, view, _html} =
        live(conn, ~p"/networks/#{network}/terminal?token=#{TerminalAuth.token(network.id)}")

      view |> form("form", invocation: %{input: "a cat on a mat"}) |> render_submit()
      run_next_invocation()

      assert has_element?(view, "#run-stats-sequence", "1")
      assert has_element?(view, "#run-stats-energy", "1.0 Wh")
    end

    test "isn't shown while the network is idle", %{conn: conn, network: network} do
      {:ok, view, _html} =
        live(conn, ~p"/networks/#{network}/terminal?token=#{TerminalAuth.token(network.id)}")

      refute has_element?(view, "#run-summary")
    end
  end

  describe "anonymous users are sent to the expired page" do
    setup do
      {:ok, network: anon_network(Fixtures.user())}
    end

    test "without a token", %{conn: conn, network: network} do
      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/networks/#{network}/terminal")

      assert path == expired_path(network)
    end

    test "with an expired token", %{conn: conn, network: network} do
      token = TerminalAuth.token(network.id, minutes_ago(11))

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/networks/#{network}/terminal?token=#{token}")

      assert path == expired_path(network)
    end

    test "with a malformed token", %{conn: conn, network: network} do
      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/networks/#{network}/terminal?token=nonsense")

      assert path == expired_path(network)
    end

    test "with another network's token", %{conn: conn, network: network} do
      other = anon_network(Fixtures.user())
      token = TerminalAuth.token(other.id)

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/networks/#{network}/terminal?token=#{token}")

      assert path == expired_path(network)
    end

    test "when the network's anonymous terminal is off", %{conn: conn, network: network} do
      token = TerminalAuth.token(network.id)
      Engine.update_network!(network, %{anon_terminal_minutes: nil}, authorize?: false)

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/networks/#{network}/terminal?token=#{token}")

      assert path == expired_path(network)
    end
  end

  describe "the QR code page" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "shows a QR code for the anonymous terminal", %{conn: conn, user: user} do
      network = anon_network(user)

      conn
      |> visit(~p"/networks/#{network}/info/qr")
      |> assert_has("#qr-modal h2", text: "scan to prompt")
      |> assert_has("#qr-modal svg")
    end

    test "says so when the network's anonymous terminal is off", %{conn: conn, user: user} do
      network = network_without_anon_terminal(user)

      conn
      |> visit(~p"/networks/#{network}/info/qr")
      |> assert_has("#qr-modal", text: "anonymous terminal is off")
      |> refute_has("#qr-modal svg")
    end

    test "is linked from the network page only when the anonymous terminal is on", %{
      conn: conn,
      user: user
    } do
      off = network_without_anon_terminal(user)
      on = anon_network(user)

      conn |> visit(~p"/networks/#{off}") |> refute_has("a", text: "QR")
      conn |> visit(~p"/networks/#{on}") |> assert_has("a[href='/networks/#{on.id}/info/qr']")
    end
  end

  describe "the QR code on a display" do
    setup %{conn: conn} do
      user = Fixtures.user()
      network = anon_network(user)

      installation =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Gallery",
            network_id: network.id,
            watchers: [
              %{
                type: :vestaboard,
                name: "board",
                stride: 1,
                offset: 0,
                vestaboard_name: :panic_1
              },
              %{type: :grid, name: "wall", rows: 2, columns: 2},
              %{type: :single, name: "spotlight", stride: 1, offset: 0}
            ]
          },
          actor: user
        )
        |> Ash.create!()

      {:ok, conn: conn, user: user, network: network, installation: installation}
    end

    defp qr_url(view) do
      view
      |> element("#terminal-qr")
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.attribute("data-url")
      |> hd()
    end

    test "is on the installation's first screen, and opens a terminal for the network", %{
      conn: conn,
      network: network,
      installation: installation
    } do
      {:ok, wall, _html} = live(conn, ~p"/i/#{installation.id}/wall")
      {:ok, spotlight, _html} = live(conn, ~p"/i/#{installation.id}/spotlight")
      {:ok, board, _html} = live(conn, ~p"/i/#{installation.id}/board")

      refute has_element?(spotlight, "#terminal-qr")
      refute has_element?(board, "#terminal-qr")

      %URI{path: path, query: query} = URI.parse(qr_url(wall))
      assert path == ~p"/networks/#{network}/terminal"
      assert {:ok, _expires_at} = TerminalAuth.verify(URI.decode_query(query)["token"], network)
    end

    test "changes every time the display refreshes it", %{conn: conn, installation: installation} do
      {:ok, wall, _html} = live(conn, ~p"/i/#{installation.id}/wall")
      before = qr_url(wall)

      # tokens carry their issue time in seconds
      Process.sleep(1100)
      send(wall.pid, :refresh_terminal_qr)

      assert qr_url(wall) != before
    end

    test "has the run in progress beside it, kept up to date", %{
      conn: conn,
      user: user,
      network: network,
      installation: installation
    } do
      Engine.start_run!(network, "a heron in the fog", actor: user)
      run_next_invocation()

      {:ok, wall, _html} = live(conn, ~p"/i/#{installation.id}/wall")
      {:ok, spotlight, _html} = live(conn, ~p"/i/#{installation.id}/spotlight")

      current = Enum.at(network.models, rem(1, length(network.models)))
      assert has_element?(wall, "#run-hud-models [aria-current]", Panic.Model.by_id(current).name)
      assert has_element?(wall, "#run-hud #run-stats-sequence", "1")
      assert has_element?(wall, "#run-hud #run-stats-energy")
      refute has_element?(wall, "#run-stats-cost")
      refute has_element?(spotlight, "#run-hud")

      run_next_invocation()
      assert has_element?(wall, "#run-hud #run-stats-sequence", "2")
    end

    test "is in a grid's last cell, with the initial prompt left to the header", %{
      conn: conn,
      user: user,
      network: network,
      installation: installation
    } do
      Engine.start_run!(network, "a heron in the fog", actor: user)
      {:ok, wall, _html} = live(conn, ~p"/i/#{installation.id}/wall")

      assert has_element?(
               wall,
               ~s(#reserved-cell[style="grid-row: 2; grid-column: 2"] #terminal-qr)
             )

      assert has_element?(wall, "#reserved-cell #run-hud")
      refute has_element?(wall, "#run-hud-prompt")
      assert render(wall) =~ "a heron in the fog"
    end

    test "is in the corner of a single first screen, beside the initial prompt", %{
      conn: conn,
      user: user,
      network: network
    } do
      installation =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Birch",
            network_id: network.id,
            watchers: [%{type: :single, name: "first", stride: 1, offset: 0}]
          },
          actor: user
        )
        |> Ash.create!()

      Engine.start_run!(network, "a heron in the fog", actor: user)
      {:ok, first, _html} = live(conn, ~p"/i/#{installation.id}/first")

      assert has_element?(first, "aside #terminal-qr")
      refute has_element?(first, "#reserved-cell")
      assert has_element?(first, "#run-hud figcaption", "initial prompt")
      assert has_element?(first, "#run-hud-prompt", "a heron in the fog")
    end

    test "has the network but no run beside it while the network is idle", %{
      conn: conn,
      installation: installation
    } do
      {:ok, wall, _html} = live(conn, ~p"/i/#{installation.id}/wall")
      assert has_element?(wall, "#terminal-qr")
      assert has_element?(wall, "#run-hud-models")
      refute has_element?(wall, "#run-hud-models [aria-current]")
      refute has_element?(wall, "#run-stats-sequence")
    end

    test "appears and disappears as the network's setting changes", %{
      conn: conn,
      network: network,
      installation: installation
    } do
      {:ok, wall, _html} = live(conn, ~p"/i/#{installation.id}/wall")
      assert has_element?(wall, "#terminal-qr")

      Engine.update_network!(network, %{anon_terminal_minutes: nil}, authorize?: false)
      refute render(wall) =~ ~s(id="terminal-qr")
      # the grid keeps its cell for the run
      assert has_element?(wall, "#reserved-cell #run-hud")

      Engine.update_network!(network, %{anon_terminal_minutes: 5}, authorize?: false)
      assert render(wall) =~ ~s(id="terminal-qr")
    end
  end
end
