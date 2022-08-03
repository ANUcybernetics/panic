defmodule PetalProWeb.OrgTeamLiveTest do
  use PetalProWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PetalPro.OrgsFixtures

  alias PetalPro.Accounts

  setup :register_and_sign_in_user

  test "lists members", %{conn: conn, org: org, user: user} do
    member = org_member_fixture(org)

    {:ok, _, html} = live(conn, Routes.org_team_path(conn, :index, org.slug))
    assert html =~ "Members"
    assert html =~ member.email
    assert html =~ user.email
  end

  test "deletes member", %{conn: conn, org: org, user: user} do
    member = org_member_fixture(org)
    token = Accounts.generate_user_session_token(Accounts.get_user!(member.id))
    PetalProWeb.Endpoint.subscribe("user_sessions:#{token}")

    {:ok, org_team_live, _} = live(conn, Routes.org_team_path(conn, :index, org.slug))

    html =
      org_team_live
      |> element("#member-#{member.id} button", "Remove")
      |> render_click()

    assert html =~ "Member deleted successfully"
    refute html =~ member.email

    assert org_team_live
           |> element("#member-#{user.id} button.disabled")
           |> has_element?()

    assert_received %Phoenix.Socket.Broadcast{event: "disconnect", topic: topic}
    assert topic == "user_sessions:" <> token

    assert_log("orgs.delete_member", %{
      user_id: user.id,
      target_user_id: member.id,
      org_id: org.id
    })
  end

  test "leave organization", %{conn: conn, org: org, user: user} do
    org_admin_fixture(org)

    {:ok, team_live, _} = live(conn, Routes.org_team_path(conn, :index, org.slug))

    {:ok, _, html} =
      team_live
      |> element("#member-#{user.id} button", "Leave")
      |> render_click()
      |> follow_redirect(conn, PetalProWeb.Helpers.home_path(user))

    assert html =~ "You have left #{org.name}"

    assert_log("orgs.delete_member", %{
      user_id: user.id,
      org_id: org.id
    })
  end

  test "create invitation", %{conn: conn, org: org} do
    {:ok, team_live, _} = live(conn, Routes.org_team_path(conn, :index, org.slug))

    assert team_live
           |> element("a", "Invite new member")
           |> render_click() =~ "<div class=\"sr-only\">Close</div>"

    assert team_live
           |> form("#form-invite", invitation: [email: "bad"])
           |> render_change() =~ "is invalid"

    invitation_email = "alice@example.com"

    {:ok, _, html} =
      team_live
      |> form("#form-invite", invitation: [email: invitation_email])
      |> render_submit()
      |> follow_redirect(conn, Routes.org_team_path(conn, :index, org.slug))

    assert html =~ "Invitation sent successfully"
    assert html =~ invitation_email
    assert_email_sent(subject: "Invitation to join #{org.name}")

    assert_log("orgs.create_invitation")
  end

  test "delete invitation", %{conn: conn, org: org} do
    invitation = invitation_fixture(org)
    {:ok, team_live, _} = live(conn, Routes.org_team_path(conn, :index, org.slug))

    html =
      team_live
      |> element("#invitation-#{invitation.id} button", "Delete")
      |> render_click()

    assert html =~ "Invitation deleted successfully"
    assert html =~ "No pending invitations."

    assert_log("orgs.delete_invitation")
  end

  test "make a member an admin", %{conn: conn, org: org} do
    member = org_member_fixture(org)

    {:ok, team_live, _} = live(conn, Routes.org_team_path(conn, :index, org.slug))

    html =
      team_live
      |> element("#member-#{member.id} a", "Edit")
      |> render_click()

    assert html =~ member.email
    assert html =~ "Save"

    {:ok, team_live, html} =
      team_live
      |> form("#form-membership", membership: [role: "admin"])
      |> render_submit()
      |> follow_redirect(conn, Routes.org_team_path(conn, :index, org.slug))

    assert html =~ "Membership updated successfully"

    team_live
    |> element("#member-#{member.id} td", "Admin")
    |> has_element?()

    assert_log("orgs.update_member", %{metadata: %{"role" => "admin"}})
  end

  test "does not allow the last admin to be removed", %{conn: conn, org: org, user: admin} do
    {:ok, team_live, _} = live(conn, Routes.org_team_path(conn, :index, org.slug))

    html =
      team_live
      |> element("#member-#{admin.id} a", "Edit")
      |> render_click()

    assert html =~ admin.email
    assert html =~ "Be careful"

    assert team_live
           |> form("#form-membership", membership: [role: "member"])
           |> render_submit() =~ "cannot remove last admin"
  end
end
