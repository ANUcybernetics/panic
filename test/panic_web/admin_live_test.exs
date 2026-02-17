defmodule PanicWeb.AdminLiveTest do
  use PanicWeb.ConnCase, async: false

  import Panic.Fixtures

  alias Panic.Engine.NetworkRegistry
  alias Panic.Engine.NetworkRunner

  setup do
    PanicWeb.Helpers.stop_all_network_runners()

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
      network1: network1,
      network2: network2
    } do
      {:ok, _} = NetworkRunner.start_run(network1.id, "test prompt 1")
      {:ok, _} = NetworkRunner.start_run(network2.id, "test prompt 2")

      assert [{_, _}] = Registry.lookup(NetworkRegistry, network1.id)
      assert [{_, _}] = Registry.lookup(NetworkRegistry, network2.id)

      session =
        conn
        |> visit("/admin")
        |> click_button("Stop all jobs")

      Process.sleep(100)

      session
      |> assert_has("#flash-info", text: "Stopped 2 running jobs")

      assert [] = Registry.lookup(NetworkRegistry, network1.id)
      assert [] = Registry.lookup(NetworkRegistry, network2.id)
    end

    test "shows appropriate message when no jobs are running", %{conn: conn} do
      PanicWeb.Helpers.stop_all_network_runners()

      conn
      |> visit("/admin")
      |> click_button("Stop all jobs")
      |> assert_has("#flash-info", text: "No running jobs found to stop")
    end

    test "shows correct message for single job", %{conn: conn, network1: network1} do
      {:ok, _} = NetworkRunner.start_run(network1.id, "test prompt")
      assert [{_, _}] = Registry.lookup(NetworkRegistry, network1.id)

      session =
        conn
        |> visit("/admin")
        |> click_button("Stop all jobs")

      Process.sleep(100)

      session
      |> assert_has("#flash-info", text: "Stopped 1 running job")
    end
  end

  describe "rendering" do
    test "displays admin panel", %{conn: conn} do
      conn
      |> visit("/admin")
      |> assert_has("header", text: "Admin panel")
      |> assert_has("button", text: "Stop all jobs")
      |> assert_has("h2", text: "Invocations")
      |> assert_has("h2", text: "Networks")
    end
  end
end
