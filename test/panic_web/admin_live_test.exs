defmodule PanicWeb.AdminLiveTest do
  use PanicWeb.ConnCase, async: false

  import Panic.Fixtures
  import Phoenix.LiveViewTest

  alias Panic.Engine.NetworkRegistry
  alias Panic.Engine.NetworkRunner

  setup do
    # Clean up any existing NetworkRunner processes
    PanicWeb.Helpers.stop_all_network_runners()

    # Patch archive_invocation_async to prevent actual archiving during tests
    Repatch.patch(NetworkRunner, :archive_invocation_async, [mode: :global], fn _invocation, _next_invocation ->
      :ok
    end)

    :ok
  end

  setup {PanicWeb.Helpers, :create_and_sign_in_user}

  setup %{user: user} do
    network1 = network_with_dummy_models(user)
    network2 = network_with_dummy_models(user)

    %{network1: network1, network2: network2}
  end

  describe "stop_all_jobs" do
    test "stops all running NetworkRunner jobs", %{
      conn: conn,
      user: _user,
      network1: network1,
      network2: network2
    } do
      # Start some NetworkRunner processes
      {:ok, _} = NetworkRunner.start_run(network1.id, "test prompt 1")
      {:ok, _} = NetworkRunner.start_run(network2.id, "test prompt 2")

      # Verify they're running
      assert [{_, _}] = Registry.lookup(NetworkRegistry, network1.id)
      assert [{_, _}] = Registry.lookup(NetworkRegistry, network2.id)

      # Mount the admin live view
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Click the stop all jobs button
      view |> element("button", "Stop all jobs") |> render_click()

      # Give a moment for processes to be terminated
      Process.sleep(100)

      # Verify the flash message
      assert view |> element("#flash-info") |> render() =~ "Stopped 2 running jobs"

      # Verify processes are no longer in registry
      # Note: processes might still be alive briefly while shutting down, but they should be removed from registry
      assert [] = Registry.lookup(NetworkRegistry, network1.id)
      assert [] = Registry.lookup(NetworkRegistry, network2.id)
    end

    test "shows appropriate message when no jobs are running", %{conn: conn} do
      # Ensure no NetworkRunner processes are running
      PanicWeb.Helpers.stop_all_network_runners()

      # Mount the admin live view
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Click the stop all jobs button
      view |> element("button", "Stop all jobs") |> render_click()

      # Verify the flash message
      assert view |> element("#flash-info") |> render() =~ "No running jobs found to stop"
    end

    test "shows correct message for single job", %{conn: conn, user: _user, network1: network1} do
      # Start one NetworkRunner process
      {:ok, _} = NetworkRunner.start_run(network1.id, "test prompt")

      # Verify it's running
      assert [{_, _}] = Registry.lookup(NetworkRegistry, network1.id)

      # Mount the admin live view
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Click the stop all jobs button
      view |> element("button", "Stop all jobs") |> render_click()

      # Give a moment for process to be terminated
      Process.sleep(100)

      # Verify the flash message
      assert view |> element("#flash-info") |> render() =~ "Stopped 1 running job"
    end
  end

  describe "rendering" do
    test "displays admin panel", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "Admin panel"
      assert html =~ "Stop all jobs"
      assert html =~ "Invocations"
      assert html =~ "Networks"
    end
  end
end
