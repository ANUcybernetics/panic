defmodule PanicWeb.AdminLiveTest do
  use PanicWeb.ConnCase, async: false

  import Panic.Fixtures

  alias Panic.Engine

  setup {PanicWeb.Helpers, :create_and_sign_in_admin_user}

  setup %{user: user} do
    network1 = network_with_dummy_models(user)
    network2 = network_with_dummy_models(user)
    %{network1: network1, network2: network2}
  end

  describe "platform keys" do
    test "saving a key stores it and shows only its last four characters", %{conn: conn} do
      session =
        conn
        |> visit("/admin")
        |> assert_has("#openai_token-status", text: "Not set")
        |> within("#credentials-form", &fill_in(&1, "OpenAI", with: "sk-test-abcd1234"))
        |> click_button("Save keys")
        |> assert_has("#openai_token-status", text: "Set, ending in 1234")

      refute_has(session, "#credentials-form input[value='sk-test-abcd1234']")

      assert {:ok, "sk-test-abcd1234"} =
               Panic.Accounts.PlatformCredentials.fetch_token(Panic.Platforms.OpenAI)
    end

    test "saving with a field left blank keeps that key", %{conn: conn} do
      set_credentials(replicate_token: "r8_keepme")

      conn
      |> visit("/admin")
      |> within("#credentials-form", &fill_in(&1, "Gemini", with: "gemini-new"))
      |> click_button("Save keys")
      |> assert_has("#replicate_token-status", text: "Set, ending in epme")
      |> assert_has("#gemini_token-status", text: "Set, ending in -new")
    end
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

    test "lists the users", %{conn: conn, user: admin} do
      user = user()

      conn
      |> visit("/admin")
      |> assert_has("#user-table", text: Ash.CiString.value(admin.email))
      |> assert_has("#user-table", text: Ash.CiString.value(user.email))
    end
  end

  describe "API keys" do
    test "creating a key shows it once and it works against the API", %{conn: conn, user: user} do
      session =
        conn
        |> visit("/admin")
        |> fill_in("Name", with: "my laptop")
        |> select("Expires", option: "In 30 days")
        |> click_button("Create API key")
        |> assert_has("#api-key-table td", text: "my laptop")

      [%{name: "my laptop", expires_at: expires_at}] = Panic.Accounts.list_api_keys!(actor: user)
      assert DateTime.diff(expires_at, DateTime.utc_now(), :day) in 29..30

      html =
        session.view
        |> Phoenix.LiveViewTest.element("#new-api-key code")
        |> Phoenix.LiveViewTest.render()

      [key] = Regex.run(~r/panic_[\w-]+/, html)

      assert build_conn()
             |> put_req_header("authorization", "Bearer " <> key)
             |> get("/api/networks")
             |> json_response(200)

      # the plaintext is gone after a reload
      conn
      |> visit("/admin")
      |> refute_has("#new-api-key")
    end

    test "revoking a key removes it", %{conn: conn, user: user} do
      Panic.Accounts.create_api_key!("old key", actor: user)

      conn
      |> visit("/admin")
      |> assert_has("#api-key-table td", text: "old key")
      |> click_button("#api-key-table button", "Revoke")
      |> assert_has("#flash-info", text: "Revoked old key")
      |> refute_has("#api-key-table")

      assert Panic.Accounts.list_api_keys!(actor: user) == []
    end
  end
end
