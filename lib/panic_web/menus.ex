defmodule PanicWeb.Menus do
  @moduledoc """
  Describe all of your navigation menus in here. This keeps you from having to define them in a layout template
  """
  import PanicWeb.Gettext
  alias PanicWeb.Router.Helpers, as: Routes
  alias PanicWeb.Endpoint
  alias PanicWeb.Helpers

  # Public menu (marketing related pages)
  def public_menu_items(_user \\ nil),
    do: [
      %{label: gettext("Features"), path: "/#features"},
      %{label: gettext("Testimonials"), path: "/#testimonials"},
      %{label: gettext("Pricing"), path: "/#pricing"}
    ]

  # Signed out main menu
  def main_menu_items(nil),
    do: []

  # Signed in main menu
  def main_menu_items(current_user),
    do:
      build_menu(
        [
          :dashboard,
          :orgs
        ],
        current_user
      )

  # Signed out user menu
  def user_menu_items(nil),
    do:
      build_menu(
        [
          :sign_in,
          :register
        ],
        nil
      )

  # Signed in user menu
  def user_menu_items(current_user),
    do:
      build_menu(
        [
          :dashboard,
          :settings,
          :admin,
          :dev,
          :sign_out
        ],
        current_user
      )

  def build_menu(menu_items, current_user \\ nil) do
    Enum.map(menu_items, fn menu_item ->
      cond do
        is_atom(menu_item) ->
          get_link(menu_item, current_user)

        is_map(menu_item) ->
          Map.merge(
            get_link(menu_item.name, current_user),
            menu_item
          )
      end
    end)
    |> Enum.filter(& &1)
  end

  def get_link(name, current_user \\ nil)

  def get_link(:register, _current_user) do
    %{
      name: :register,
      label: "Register",
      path: Routes.user_registration_path(Endpoint, :new),
      icon: :clipboard_list
    }
  end

  def get_link(:sign_in, _current_user) do
    %{
      name: :sign_in,
      label: "Sign in",
      path: Routes.user_session_path(Endpoint, :new),
      icon: :key
    }
  end

  def get_link(:sign_out, _current_user) do
    %{
      name: :sign_out,
      label: "Sign out",
      path: Routes.user_session_path(Endpoint, :delete),
      icon: :logout,
      method: :delete
    }
  end

  def get_link(:settings, _current_user) do
    %{
      name: :settings,
      label: gettext("Settings"),
      path: Routes.live_path(Endpoint, PanicWeb.EditProfileLive),
      icon: :cog
    }
  end

  def get_link(:edit_profile, _current_user) do
    %{
      name: :edit_profile,
      label: gettext("Edit profile"),
      path: Routes.live_path(Endpoint, PanicWeb.EditProfileLive),
      icon: :user_circle
    }
  end

  def get_link(:edit_email, _current_user) do
    %{
      name: :edit_email,
      label: gettext("Change email"),
      path: Routes.live_path(Endpoint, PanicWeb.EditEmailLive),
      icon: :at_symbol
    }
  end

  def get_link(:edit_notifications, _current_user) do
    %{
      name: :edit_notifications,
      label: gettext("Edit notifications"),
      path: Routes.live_path(Endpoint, PanicWeb.EditNotificationsLive),
      icon: :bell
    }
  end

  def get_link(:edit_password, _current_user) do
    %{
      name: :edit_password,
      label: gettext("Edit password"),
      path: Routes.live_path(Endpoint, PanicWeb.EditPasswordLive),
      icon: :key
    }
  end

  def get_link(:org_invitations, _current_user) do
    %{
      name: :org_invitations,
      label: gettext("Invitations"),
      path: Routes.live_path(Endpoint, PanicWeb.UserOrgInvitationsLive),
      icon: :mail
    }
  end

  def get_link(:edit_totp, _current_user) do
    %{
      name: :edit_totp,
      label: gettext("2FA"),
      path: Routes.live_path(Endpoint, PanicWeb.EditTotpLive),
      icon: :shield_check
    }
  end

  def get_link(:dashboard, _current_user) do
    %{
      name: :dashboard,
      label: gettext("Dashboard"),
      path: Routes.live_path(Endpoint, PanicWeb.DashboardLive),
      icon: :template
    }
  end

  def get_link(:orgs, _current_user) do
    %{
      name: :orgs,
      label: gettext("Organizations"),
      path: Routes.orgs_path(Endpoint, :index),
      icon: :office_building
    }
  end

  def get_link(:admin, current_user) do
    link = get_link(:admin_users, current_user)

    if link do
      link
      |> Map.put(:label, "Admin")
      |> Map.put(:icon, :lock_closed)
    end
  end

  def get_link(:admin_users = name, current_user) do
    if Helpers.is_admin?(current_user) do
      %{
        name: name,
        label: "Users",
        path: Routes.admin_users_path(Endpoint, :index),
        icon: :users
      }
    end
  end

  def get_link(:dev = name, _current_user) do
    if Panic.config(:env) == :dev do
      %{
        name: name,
        label: "Dev",
        path: "/dev",
        icon: :code
      }
    end
  end

  def get_link(:dev_email_templates = name, _current_user) do
    if Panic.config(:env) == :dev do
      %{
        name: name,
        label: "Email templates",
        path: "/dev/emails",
        icon: :template
      }
    end
  end

  def get_link(:dev_sent_emails = name, _current_user) do
    if Panic.config(:env) == :dev do
      %{
        name: name,
        label: "Sent emails",
        path: "/dev/emails/sent",
        icon: :at_symbol
      }
    end
  end
end
