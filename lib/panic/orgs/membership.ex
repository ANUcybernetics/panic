defmodule Panic.Orgs.Membership do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  import PanicWeb.Gettext

  alias Panic.Orgs.Org
  alias Panic.Accounts.User

  @default_role "member"
  @admin_role "admin"

  schema "orgs_memberships" do
    field :role, :string

    belongs_to :user, User
    belongs_to :org, Org

    timestamps()
  end

  def by_user_and_org_slug(%User{} = user, org_slug) do
    from(ms in __MODULE__,
      join: org in assoc(ms, :org),
      on: [slug: ^org_slug],
      where: ms.user_id == ^user.id
    )
  end

  def all_by_org(%Org{} = org) do
    from(m in __MODULE__,
      join: u in assoc(m, :user),
      join: o in assoc(m, :org),
      on: o.id == ^org.id,
      preload: [:user]
    )
  end

  def insert_changeset(org, user, role \\ @default_role) do
    change(%__MODULE__{
      org_id: org.id,
      user_id: user.id,
      role: role
    })
    |> unique_constraint([:org_id, :user_id])
  end

  def update_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, ~w[admin member])
    |> prepare_changes(fn changeset ->
      current_role = membership.role
      new_role = get_change(changeset, :role)

      if current_role == @admin_role && new_role != current_role do
        validate_at_least_one_admin(changeset)
      else
        changeset
      end
    end)
  end

  def delete_changeset(%__MODULE__{} = membership) do
    membership
    |> change()
    |> prepare_changes(&validate_at_least_one_admin/1)
  end

  defp validate_at_least_one_admin(changeset) do
    org_id = changeset.data.org_id
    user_id = changeset.data.user_id

    query =
      from(m in __MODULE__,
        where: m.org_id == ^org_id and m.role == @admin_role and m.user_id != ^user_id,
        select: count(1)
      )

    if changeset.repo.one!(query) > 0 do
      changeset
    else
      add_error(changeset, :role, gettext("cannot remove last admin of the organization"))
    end
  end
end
