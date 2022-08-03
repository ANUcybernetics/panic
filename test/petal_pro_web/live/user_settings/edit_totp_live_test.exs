defmodule PetalProWeb.EditTotpLiveTest do
  use PetalProWeb.ConnCase
  import Phoenix.LiveViewTest
  import PetalPro.AccountsFixtures
  alias PetalPro.{Repo, Accounts}

  setup :register_and_sign_in_user

  describe "Index (2FA)" do
    @backup_codes_message "Keep these backup codes safe"
    @enter_your_current_password_to_enable "Enter your current password to enable"
    @enter_your_current_password_to_change "Enter your current password to change"

    test "requires password to enable 2FA", %{conn: conn} do
      {:ok, view, html} = live(conn, Routes.live_path(conn, PetalProWeb.EditTotpLive))

      assert html =~ "Two-factor authentication"
      assert html =~ @enter_your_current_password_to_enable

      html =
        view
        |> form("#form-submit-totp", user: %{current_password: "bad"})
        |> render_submit()

      assert html =~ "is not valid"
      assert view |> element("input[type='password']") |> render() =~ "value="

      html =
        view
        |> form("#form-submit-totp", user: %{current_password: valid_user_password()})
        |> render_submit()

      assert html =~ "Authentication code"
      refute html =~ @enter_your_current_password_to_enable

      assert view |> element("#cancel-totp", "Cancel") |> render_click() =~
               @enter_your_current_password_to_enable

      refute view |> element("input[type='password']") |> render() =~ "value="
    end

    test "enables totp secret", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, Routes.live_path(conn, PetalProWeb.EditTotpLive))

      view
      |> form("#form-submit-totp", user: %{current_password: valid_user_password()})
      |> render_submit()

      assert view
             |> form("#form-update-totp", user_totp: [code: "123"])
             |> render_submit() =~ "should be a 6 digit number"

      view
      |> element("a", "enter your secret")
      |> render_click()

      html =
        view
        |> form("#form-update-totp", user_totp: [code: get_otp(view)])
        |> render_submit()

      # Now we show all backup codes
      assert html =~ @backup_codes_message

      assert_log("totp.enable", user_id: user.id)

      html =
        view
        |> element("#close-backup-codes")
        |> render_click()

      # Until we close the modal and see the whole page
      refute html =~ @backup_codes_message
      assert html =~ "2FA Enabled"
      assert html =~ @enter_your_current_password_to_change

      # Finally, check there is no lingering password on the initial form
      refute view |> element("input[type='password']") |> render() =~ "value="
    end

    test "disables 2FA password", %{conn: conn, user: user} do
      totp = user_totp_fixture(user)

      {:ok, view, html} = live(conn, Routes.live_path(conn, PetalProWeb.EditTotpLive))
      assert html =~ @enter_your_current_password_to_change

      assert view
             |> form("#form-submit-totp", user: %{current_password: valid_user_password()})
             |> render_submit() =~
               "Authentication code"

      assert view |> element("#disable-totp") |> render_click() =~
               @enter_your_current_password_to_enable

      refute Repo.get(Accounts.UserTOTP, totp.id)
      assert_log("totp.disable", user_id: user.id)
    end

    test "changes totp secret", %{conn: conn, user: user} do
      totp = user_totp_fixture(user)
      {:ok, view, _html} = live(conn, Routes.live_path(conn, PetalProWeb.EditTotpLive))

      view
      |> form("#form-submit-totp", user: %{current_password: valid_user_password()})
      |> render_submit()

      view
      |> element("a", "enter your secret")
      |> render_click()

      html =
        view
        |> form("#form-update-totp", user_totp: [code: get_otp(view)])
        |> render_submit()

      assert html =~ "2FA Enabled"
      assert html =~ @enter_your_current_password_to_change
      assert_log("totp.update", user_id: user.id)

      refute view |> element("input[type='password']") |> render() =~ "value="

      assert Repo.get!(Accounts.UserTOTP, totp.id).secret !=
               valid_totp_secret()
    end

    test "regenerates backup codes", %{conn: conn, user: user} do
      %{backup_codes: [backup_code | backup_codes]} = totp = user_totp_fixture(user)
      used_code = Ecto.Changeset.change(backup_code, used_at: DateTime.utc_now())

      totp
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_embed(:backup_codes, [used_code | backup_codes])
      |> Repo.update!()

      {:ok, view, _html} = live(conn, Routes.live_path(conn, PetalProWeb.EditTotpLive))

      view
      |> form("#form-submit-totp", user: %{current_password: valid_user_password()})
      |> render_submit()

      view
      |> element("a", "enter your secret")
      |> render_click()

      otp_secret = get_otp(view)

      html =
        view
        |> element("#show-backup")
        |> render_click()

      # We can now see all backup codes and one of them is marked as del
      assert html =~ @backup_codes_message
      assert view |> element("del", backup_code.code) |> has_element?()

      html =
        view
        |> element("#regenerate-backup")
        |> render_click()

      # We are on the same page, with the same secret, but we got new tokens
      assert html =~ @backup_codes_message
      refute html =~ backup_code.code
      assert get_otp(view) == otp_secret
      assert_log("totp.regenerate_backup_codes", user_id: user.id)

      # Also make sure the changes were reflected in the database
      updated_totp = Repo.get!(Accounts.UserTOTP, totp.id)
      assert updated_totp.secret == totp.secret
      assert Enum.all?(updated_totp.backup_codes, &is_nil(&1.used_at))
      assert Enum.all?(updated_totp.backup_codes, &(html =~ &1.code))

      # Now we close and reopen to find the same token
      view
      |> element("#close-backup-codes")
      |> render_click()

      html =
        view
        |> element("#show-backup")
        |> render_click()

      assert Enum.all?(updated_totp.backup_codes, &(html =~ &1.code))
    end

    defp get_otp(live) do
      live
      |> element("#totp-secret")
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.text()
      |> String.replace(~r/\s/, "")
      |> Base.decode32!()
      |> NimbleTOTP.verification_code()
    end
  end
end
