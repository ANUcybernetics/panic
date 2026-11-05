defmodule PanicWeb.RedirectLiveTest do
  use PanicWeb.ConnCase, async: false

  import PanicWeb.Helpers

  describe "Redirect functionality" do
    test "redirects static invocation pattern for anonymous users", %{conn: conn} do
      assert conn |> get(~p"/r/s12345") |> redirected_to() == "/display/static/12345/"
    end

    test "redirects static invocation pattern for authenticated users", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})

      assert conn |> get(~p"/r/s12345") |> redirected_to() == "/display/static/12345/"
    end

    test "redirects unknown patterns to home", %{conn: conn} do
      assert conn |> get(~p"/r/abc") |> redirected_to() == "/"
    end

    test "handles invocation ID with multiple characters", %{conn: conn} do
      assert conn |> get(~p"/r/sabcdef123") |> redirected_to() == "/display/static/abcdef123/"
    end
  end
end
