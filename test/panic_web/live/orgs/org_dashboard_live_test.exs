defmodule PanicWeb.OrgDashboardLiveTest do
  use PanicWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Panic.OrgsFixtures

  setup :register_and_sign_in_user

  describe "has role 'admin'" do
    test "can access and see name and settings", %{conn: conn, user: user} do
      org = org_fixture()
      membership_fixture(org, user, "admin")

      {:ok, view, html} =
        live(conn, Routes.live_path(conn, PanicWeb.OrgDashboardLive, org.slug))

      assert html =~ org.name
      assert has_element?(view, "#sidebar span", "Settings")
    end
  end

  describe "has role 'member'" do
    test "can access but doesn't see settings", %{conn: conn, user: user} do
      org = org_fixture()
      membership_fixture(org, user, "member")

      {:ok, view, html} =
        live(conn, Routes.live_path(conn, PanicWeb.OrgDashboardLive, org.slug))

      assert html =~ org.name
      refute has_element?(view, "#sidebar span", "Settings")
    end
  end

  describe "is not a member" do
    test "redirects", %{conn: conn, user: user} do
      org = org_fixture()
      membership_fixture(org, user, "member")

      assert {:error,
              {:redirect,
               %{flash: %{"error" => "You do not have permission to access this page."}}}} =
               live(conn, Routes.live_path(conn, PanicWeb.EditOrgLive, org.slug))
    end
  end
end
