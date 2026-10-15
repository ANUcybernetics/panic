defmodule PanicWeb.BackupControllerTest do
  use PanicWeb.ConnCase

  alias PanicWeb.Helpers

  describe "download/2" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/admin/backup")
      # The authentication plug returns 403 for unauthenticated requests to regular controllers
      assert json_response(conn, 403) == %{"error" => "Forbidden"}
    end

    @tag :capture_log
    test "returns forbidden for non-admin users", %{conn: conn} do
      %{conn: conn, user: _user} = Helpers.create_and_sign_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/backup")

      assert json_response(conn, 403) == %{"error" => "Forbidden"}
    end
  end
end
