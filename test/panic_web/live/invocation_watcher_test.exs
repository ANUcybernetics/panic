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

  alias Panic.Engine.NetworkRunner
  alias Panic.Fixtures
  alias Phoenix.Socket.Broadcast

  setup do
    Panic.ExternalAPIPatches.setup()
    PanicWeb.Helpers.setup_web_test()

    on_exit(fn ->
      Panic.ExternalAPIPatches.teardown()
    end)

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

    test "assigns current_invocation when broadcast arrives", %{conn: conn, network: network} do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      {:ok, _genesis} = NetworkRunner.start_run(network.id, "watcher test")
      Process.sleep(50)

      html = render(view)
      assert html =~ "watcher test"

      NetworkRunner.stop_run(network.id)
    end

    test "shows runner status component with processing state", %{conn: conn, network: network} do
      {:ok, view, html} = live(conn, ~p"/networks/#{network}")

      assert html =~ "Idle"

      {:ok, _genesis} = NetworkRunner.start_run(network.id, "status test")
      Process.sleep(50)

      html = render(view)
      assert html =~ "Sequence"

      NetworkRunner.stop_run(network.id)
    end

    test "populates invocation stream via hook", %{conn: conn, network: network} do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      {:ok, _genesis} = NetworkRunner.start_run(network.id, "stream test")
      Process.sleep(50)

      html = render(view)
      assert html =~ "stream test"

      NetworkRunner.stop_run(network.id)
    end

    test "updates genesis invocation on new run", %{conn: conn, network: network, user: user} do
      network =
        network
        |> Ash.Changeset.for_update(:update, %{lockout_seconds: 0}, actor: user)
        |> Ash.update!()

      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      {:ok, _genesis1} = NetworkRunner.start_run(network.id, "first run")
      Process.sleep(50)
      assert render(view) =~ "first run"

      {:ok, _genesis2} = NetworkRunner.start_run(network.id, "second run")
      Process.sleep(50)
      assert render(view) =~ "second run"

      NetworkRunner.stop_run(network.id)
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

    test "sets data-ready-at after a run starts", %{conn: conn, network: network} do
      {:ok, view, html} = live(conn, ~p"/networks/#{network}")

      refute html =~ "data-ready-at"

      {:ok, _genesis} = NetworkRunner.start_run(network.id, "lockout test")
      Process.sleep(50)

      html = render(view)
      assert html =~ "data-ready-at"

      NetworkRunner.stop_run(network.id)
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

    test "shows genesis input after starting a run", %{conn: conn, network: network} do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network.id}/terminal")

      {:ok, _genesis} = NetworkRunner.start_run(network.id, "terminal watcher test")
      Process.sleep(50)

      html = render(view)
      assert html =~ "terminal watcher test"

      NetworkRunner.stop_run(network.id)
    end

    test "submitting prompt updates genesis display", %{conn: conn, network: network} do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network.id}/terminal")

      view
      |> form("form", invocation: %{input: "submitted prompt"})
      |> render_submit()

      Process.sleep(50)

      html = render(view)
      assert html =~ "submitted prompt"

      NetworkRunner.stop_run(network.id)
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
