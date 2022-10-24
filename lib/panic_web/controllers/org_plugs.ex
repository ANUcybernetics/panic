defmodule PanicWeb.OrgPlugs do
  import Plug.Conn
  import Phoenix.Controller
  import PanicWeb.Gettext

  def assign_org_data(conn, _opts) do
    orgs = Panic.Orgs.list_orgs(conn.assigns.current_user)

    conn
    |> assign(:orgs, orgs)
    |> assign(
      :current_membership,
      conn.params["org_slug"] &&
        Panic.Orgs.get_membership!(conn.assigns.current_user, conn.params["org_slug"])
    )
    |> assign(:current_org, Enum.find(orgs, &(&1.slug == conn.params["org_slug"])))
  end

  # Must be run after :assign_org_data
  def require_org_member(conn, _opts) do
    membership = conn.assigns.current_membership

    if membership do
      conn
    else
      conn
      |> put_flash(:error, gettext("You do not have permission to access this page."))
      |> redirect(to: PanicWeb.Helpers.home_path(conn.assigns.current_user))
      |> halt()
    end
  end

  # Must be run after :assign_org_data
  def require_org_admin(conn, _opts) do
    membership = conn.assigns.current_membership

    if membership.role == :admin do
      conn
    else
      conn
      |> put_flash(:error, gettext("You do not have permission to access this page."))
      |> redirect(to: PanicWeb.Helpers.home_path(conn.assigns.current_user))
      |> halt()
    end
  end
end
