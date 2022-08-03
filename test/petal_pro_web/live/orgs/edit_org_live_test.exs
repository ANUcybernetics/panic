defmodule PetalProWeb.EditOrgLiveTest do
  use PetalProWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PetalPro.OrgsFixtures
  alias PetalPro.Repo
  alias PetalPro.Orgs.Org

  setup :register_and_sign_in_user

  describe "valid params" do
    test "can edit an org", %{conn: conn, org: org, user: _user} do
      edit_org_path = Routes.live_path(conn, PetalProWeb.EditOrgLive, org.slug)
      current_slug = org.slug
      {:ok, view, _html} = live(conn, edit_org_path)

      new_name = "Something new"

      {:ok, _view, html} =
        view
        |> form("form", org: %{name: new_name})
        |> render_submit()
        |> follow_redirect(conn, edit_org_path)

      assert html =~ new_name
      assert html =~ "Organization updated"

      org = Repo.last(Org)
      assert org.name == new_name
      assert org.slug == current_slug
    end
  end

  describe "invalid params" do
    test "shows errors", %{conn: conn, org: org, user: _user} do
      {:ok, view, _html} = live(conn, Routes.live_path(conn, PetalProWeb.EditOrgLive, org.slug))

      assert view
             |> form("form")
             |> render_change(%{org: %{name: "d"}}) =~ "should be at least 2 character"
    end
  end

  describe "not admin" do
    test "it redirects", %{conn: conn, org: _org, user: user} do
      new_org = org_fixture()
      membership_fixture(new_org, user, "member")

      assert {:error,
              {:redirect,
               %{flash: %{"error" => "You do not have permission to access this page."}}}} =
               live(conn, Routes.live_path(conn, PetalProWeb.EditOrgLive, new_org.slug))
    end
  end
end
