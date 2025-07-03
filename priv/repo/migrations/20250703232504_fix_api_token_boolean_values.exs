defmodule Panic.Repo.Migrations.FixApiTokenBooleanValues do
  use Ecto.Migration

  def up do
    execute """
    UPDATE api_tokens
    SET allow_anonymous_use = CASE
      WHEN allow_anonymous_use = 'false' THEN 0
      WHEN allow_anonymous_use = 'true' THEN 1
      WHEN allow_anonymous_use = '0' THEN 0
      WHEN allow_anonymous_use = '1' THEN 1
      ELSE allow_anonymous_use
    END
    """
  end

  def down do
    # No need to reverse this fix
  end
end