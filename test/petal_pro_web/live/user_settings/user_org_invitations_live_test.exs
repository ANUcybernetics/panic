defmodule PetalProWeb.UserOrgInvitationsLiveTest do
  use PetalProWeb.ConnCase
  alias PetalPro.Repo
  alias PetalPro.Orgs.Invitation
  import Phoenix.LiveViewTest
  import PetalPro.OrgsFixtures

  setup :register_and_sign_in_user

  describe "when invitations are present" do
    test "can't see invitations when not confirmed", %{conn: conn, user: user, org: _org} do
      Repo.update(Ecto.Changeset.change(user, %{confirmed_at: nil}))
      {:ok, _, html} = live(conn, Routes.live_path(conn, PetalProWeb.UserOrgInvitationsLive))
      assert html =~ "You may have pending invitations"
      assert html =~ "confirm your account"
      refute html =~ "You have no pending invitations"
    end

    test "can accept an invitation", %{conn: conn, user: user, org: _org} do
      new_org = org_fixture()
      invitation_fixture(new_org, %{email: user.email})
      {:ok, view, html} = live(conn, Routes.live_path(conn, PetalProWeb.UserOrgInvitationsLive))
      assert html =~ new_org.name
      assert Repo.count(Invitation) == 1

      assert view
             |> element("button", "Accept")
             |> render_click() =~ "Invitation was accepted"

      assert_log("orgs.accept_invitation", %{user_id: user.id, org_id: new_org.id})
      assert Repo.count(Invitation) == 0
    end

    test "can reject an invitation", %{conn: conn, user: user, org: _org} do
      new_org = org_fixture()
      invitation_fixture(new_org, %{email: user.email})
      {:ok, view, html} = live(conn, Routes.live_path(conn, PetalProWeb.UserOrgInvitationsLive))
      assert html =~ new_org.name
      assert Repo.count(Invitation) == 1

      html =
        view
        |> element("button", "Reject")
        |> render_click()

      assert html =~ "Invitation was rejected"
      assert html =~ "You have no pending invitations"
      assert_log("orgs.reject_invitation", %{user_id: user.id, org_id: new_org.id})
      assert Repo.count(Invitation) == 0
    end
  end

  describe "when there are no invitations" do
    test "lets the user know there are none", %{conn: conn, user: _user, org: _org} do
      {:ok, _view, html} = live(conn, Routes.live_path(conn, PetalProWeb.UserOrgInvitationsLive))
      assert html =~ "You have no pending invitations"
    end
  end
end
