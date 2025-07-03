defmodule Panic.Repo.Migrations.RemoveTokenFieldsFromUsers do
  @moduledoc """
  Removes the old token fields from the users table after migration to APIToken resource.
  """
  
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :replicate_token
      remove :openai_token
      remove :gemini_token
      remove :vestaboard_panic_1_token
      remove :vestaboard_panic_2_token
      remove :vestaboard_panic_3_token
      remove :vestaboard_panic_4_token
    end
  end
end