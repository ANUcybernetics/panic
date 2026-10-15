defmodule PanicWeb.AdminLiveTest do
  use PanicWeb.ConnCase, async: false

  import Panic.Fixtures

  alias Panic.Engine

  setup {PanicWeb.Helpers, :create_and_sign_in_user}

  setup %{user: user} do
    network1 = network_with_dummy_models(user)
    network2 = network_with_dummy_models(user)
    %{network1: network1, network2: network2}
  end

  describe "stop_all_jobs" do
    test "stops every running network", %{
      conn: conn,
      user: user,
      network1: network1,
      network2: network2
    } do
      Engine.start_run!(network1, "test prompt 1", actor: user)
      Engine.start_run!(network2, "test prompt 2", actor: user)

      conn
      |> visit("/admin")
      |> click_button("Stop all jobs")
      |> assert_has("#flash-info", text: "Stopped 2 running jobs")

      assert [] = Engine.list_running_networks!(authorize?: false)
    end

    test "shows appropriate message when no jobs are running", %{conn: conn} do
      conn
      |> visit("/admin")
      |> click_button("Stop all jobs")
      |> assert_has("#flash-info", text: "No running jobs found to stop")
    end

    test "shows correct message for single job", %{conn: conn, user: user, network1: network1} do
      Engine.start_run!(network1, "test prompt", actor: user)

      conn
      |> visit("/admin")
      |> click_button("Stop all jobs")
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
