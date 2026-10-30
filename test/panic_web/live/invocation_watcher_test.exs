defmodule PanicWeb.InvocationWatcherTest do
  @moduledoc """
  Tests for the invocation watcher infrastructure.

  Verifies that the WatcherSubscriber on_mount hook correctly:
  - Assigns `current_invocation` from broadcast payloads
  - Populates the invocation stream via the hook
  - Updates RunnerStatusComponent status based on current_invocation
  - Sets `data-ready-at` for client-side lockout timer
  """
  use PanicWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Panic.Engine
  alias Panic.Fixtures
  alias Phoenix.Socket.Broadcast

  setup do
    Panic.ExternalAPIPatches.setup()

    :ok
  end

  describe "invocation watcher hook on Show page" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    setup %{user: user} do
      network = Fixtures.network_with_dummy_models(user)

      network =
        network
        |> Ash.Changeset.for_update(:update, %{lockout_seconds: 10}, actor: user)
        |> Ash.update!()

      {:ok, network: network}
    end

    test "assigns current_invocation when broadcast arrives", %{
      conn: conn,
      network: network,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      _genesis = Engine.start_run!(network, "watcher test", actor: user)

      html = render(view)
      assert html =~ "watcher test"
    end

    test "shows runner status component with processing state", %{
      conn: conn,
      network: network,
      user: user
    } do
      {:ok, view, html} = live(conn, ~p"/networks/#{network}")

      assert html =~ "Idle"

      _genesis = Engine.start_run!(network, "status test", actor: user)

      html = render(view)
      assert html =~ "Sequence"
    end

    test "populates invocation stream via hook", %{conn: conn, network: network, user: user} do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      _genesis = Engine.start_run!(network, "stream test", actor: user)

      html = render(view)
      assert html =~ "stream test"
    end

    test "updates genesis invocation on new run", %{conn: conn, network: network, user: user} do
      network =
        network
        |> Ash.Changeset.for_update(:update, %{lockout_seconds: 0}, actor: user)
        |> Ash.update!()

      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      _genesis1 = Engine.start_run!(network, "first run", actor: user)
      assert render(view) =~ "first run"

      _genesis2 = Engine.start_run!(network, "second run", actor: user)
      assert render(view) =~ "second run"
    end

    test "shows a countdown while the next invocation waits", %{
      conn: conn,
      network: network,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      Engine.start_run!(network, "countdown test", actor: user)
      Panic.EngineHelpers.run_next_invocation()

      assert has_element?(view, "#runner-status", "Waiting")
      assert has_element?(view, "#countdown[data-target-time]")
    end

    test "stopping the run returns every viewer to idle", %{
      conn: conn,
      network: network,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")
      Engine.start_run!(network, "stop test", actor: user)
      assert has_element?(view, "#runner-status", "Waiting")

      view |> element("button", "Stop") |> render_click()

      assert has_element?(view, "#runner-status", "Idle")
    end
  end

  describe "lockout timer data attribute" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    setup %{user: user} do
      network = Fixtures.network_with_dummy_models(user)

      network =
        network
        |> Ash.Changeset.for_update(:update, %{lockout_seconds: 30}, actor: user)
        |> Ash.update!()

      {:ok, network: network}
    end

    test "sets data-ready-at after a run starts", %{conn: conn, network: network, user: user} do
      {:ok, view, html} = live(conn, ~p"/networks/#{network}")

      refute html =~ "data-ready-at"

      _genesis = Engine.start_run!(network, "lockout test", actor: user)

      html = render(view)
      assert html =~ "data-ready-at"
    end
  end

  describe "terminal page watcher" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    setup %{user: user} do
      network = Fixtures.network_with_dummy_models(user)

      network =
        network
        |> Ash.Changeset.for_update(:update, %{lockout_seconds: 0}, actor: user)
        |> Ash.update!()

      {:ok, network: network}
    end

    test "shows genesis input after starting a run", %{conn: conn, network: network, user: user} do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network.id}/terminal")

      _genesis = Engine.start_run!(network, "terminal watcher test", actor: user)

      html = render(view)
      assert html =~ "terminal watcher test"
    end

    test "submitting prompt updates genesis display", %{conn: conn, network: network} do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network.id}/terminal")

      view
      |> form("form", invocation: %{input: "submitted prompt"})
      |> render_submit()

      html = render(view)
      assert html =~ "submitted prompt"
    end
  end

  describe "broadcast handling without hook (AdminLive)" do
    setup {PanicWeb.Helpers, :create_and_sign_in_admin_user}

    test "admin page handles invocation broadcasts directly", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin")
      assert html =~ "Admin"

      # Verify the admin page doesn't crash when receiving broadcasts
      # (AdminLive handles them in its own handle_info, not via the hook)
      send(view.pid, %Broadcast{
        topic: "invocation:fake",
        event: "presence_diff",
        payload: %{}
      })

      Process.sleep(10)
      assert render(view) =~ "Admin"
    end
  end
end
