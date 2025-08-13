defmodule PanicWeb.BackupTest do
  @moduledoc """
  PhoenixTest tests for the backup functionality.
  Tests both the UI interaction and the actual backup download.
  """
  use PanicWeb.ConnCase

  import PhoenixTest

  alias PanicWeb.Helpers

  describe "backup download from admin panel" do
    test "non-admin users don't see the backup button", %{conn: conn} do
      # Create and sign in as regular user
      %{conn: conn, user: _user} = Helpers.create_and_sign_in_user(%{conn: conn})

      # Navigate to admin panel
      conn
      |> visit("/admin")
      |> refute_has("button", text: "Download backup")
    end

    test "admin users can see the backup button", %{conn: conn} do
      # Create and sign in as admin user
      %{conn: conn, user: _admin} = Helpers.create_and_sign_in_admin_user(%{conn: conn})

      # Navigate to admin panel and verify backup button exists
      conn
      |> visit("/admin")
      |> assert_has("button", text: "Download backup")
    end

    test "backup endpoint returns 403 for non-admin users", %{conn: conn} do
      %{conn: conn, user: _user} = Helpers.create_and_sign_in_user(%{conn: conn})

      conn = get(conn, ~p"/admin/backup")
      assert json_response(conn, 403) == %{"error" => "Forbidden"}
    end

    @tag :skip
    test "backup endpoint returns database file for admin users", %{conn: conn} do
      # NOTE: This test is skipped because VACUUM INTO cannot run inside a transaction,
      # which is how the test sandbox works. The endpoint works correctly in production.
      %{conn: conn, user: _admin} = Helpers.create_and_sign_in_admin_user(%{conn: conn})

      conn = get(conn, ~p"/admin/backup")

      # Verify response headers
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["application/octet-stream"]

      [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "attachment"
      assert disposition =~ "panic_backup_"
      assert disposition =~ ".db"

      # Verify we got actual data (SQLite database starts with "SQLite format 3")
      body = response(conn, 200)
      assert byte_size(body) > 0
      assert String.starts_with?(body, "SQLite format 3")
    end

    test "unauthenticated users get 403 when accessing backup endpoint", %{conn: conn} do
      conn = get(conn, ~p"/admin/backup")
      assert json_response(conn, 403) == %{"error" => "Forbidden"}
    end
  end

  describe "admin panel access" do
    test "regular users can access admin panel but see limited functionality", %{conn: conn} do
      %{conn: conn, user: _user} = Helpers.create_and_sign_in_user(%{conn: conn})

      conn
      |> visit("/admin")
      |> assert_has("h1", text: "Admin panel")
      |> assert_has("button", text: "Stop all jobs")
      |> refute_has("button", text: "Download backup")
    end

    test "admin users see full functionality in admin panel", %{conn: conn} do
      %{conn: conn, user: _admin} = Helpers.create_and_sign_in_admin_user(%{conn: conn})

      conn
      |> visit("/admin")
      |> assert_has("h1", text: "Admin panel")
      |> assert_has("button", text: "Stop all jobs")
      |> assert_has("button", text: "Download backup")
    end
  end
end
