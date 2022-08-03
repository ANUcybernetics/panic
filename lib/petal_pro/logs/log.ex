defmodule PetalPro.Logs.Log do
  use Ecto.Schema
  import Ecto.Changeset
  use QueryBuilder

  @user_type_options ["user", "admin"]
  @action_options [
    "update_profile",
    "register",
    "sign_in",
    "passwordless_pin_sent",
    "passwordless_pin_too_many_incorrect_attempts",
    "sign_out",
    "confirm_email",
    "request_new_email",
    "confirm_new_email",
    "delete_user",
    "orgs.create",
    "orgs.delete_member",
    "orgs.update_member",
    "orgs.create_invitation",
    "orgs.delete_invitation",
    "orgs.accept_invitation",
    "orgs.reject_invitation",
    "totp.enable",
    "totp.update",
    "totp.disable",
    "totp.regenerate_backup_codes",
    "totp.validate",
    "totp.validate_with_backup_code",
    "totp.invalid_code_used"
  ]

  schema "logs" do
    field :action, :string
    field :user_type, :string, default: "user"
    field :metadata, :map, default: %{}

    belongs_to :user, PetalPro.Accounts.User
    belongs_to :target_user, PetalPro.Accounts.User
    belongs_to :org, PetalPro.Orgs.Org

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [
      :action,
      :user_type,
      :user_id,
      :org_id,
      :target_user_id,
      :inserted_at,
      :metadata
    ])
    |> validate_required([
      :action,
      :user_type,
      :user_id
    ])
    |> validate_inclusion(:action, @action_options)
    |> validate_inclusion(:user_type, @user_type_options)
  end

  def action_options, do: @action_options
end
