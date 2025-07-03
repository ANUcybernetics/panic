defmodule Panic.Repo.Migrations.MigrateUserTokensToApiTokens do
  @moduledoc """
  Migrates existing user tokens to the new APIToken resource.

  This migration:
  1. Creates an APIToken for each user that has at least one token
  2. Copies all token values from the user to the new APIToken
  3. Creates the join table relationship between user and APIToken
  4. Sets allow_anonymous_use to false for all migrated tokens
  """

  use Ecto.Migration
  import Ecto.Query

  def up do
    # Get all users with at least one token
    users_with_tokens =
      from(u in "users",
        where:
          not is_nil(u.replicate_token) or
            not is_nil(u.openai_token) or
            not is_nil(u.gemini_token) or
            not is_nil(u.vestaboard_panic_1_token) or
            not is_nil(u.vestaboard_panic_2_token) or
            not is_nil(u.vestaboard_panic_3_token) or
            not is_nil(u.vestaboard_panic_4_token),
        select: %{
          id: u.id,
          email: u.email,
          replicate_token: u.replicate_token,
          openai_token: u.openai_token,
          gemini_token: u.gemini_token,
          vestaboard_panic_1_token: u.vestaboard_panic_1_token,
          vestaboard_panic_2_token: u.vestaboard_panic_2_token,
          vestaboard_panic_3_token: u.vestaboard_panic_3_token,
          vestaboard_panic_4_token: u.vestaboard_panic_4_token
        }
      )
      |> Panic.Repo.all()

    # Create APIToken for each user and link them
    Enum.each(users_with_tokens, fn user ->
      # Generate a name for the token set
      token_name = "Personal Tokens - #{user.email}"

      # Insert the APIToken
      {:ok, %{rows: [[api_token_id]]}} =
        Ecto.Adapters.SQL.query(
          Panic.Repo,
          """
          INSERT INTO api_tokens (
            name,
            replicate_token,
            openai_token,
            gemini_token,
            vestaboard_panic_1_token,
            vestaboard_panic_2_token,
            vestaboard_panic_3_token,
            vestaboard_panic_4_token,
            allow_anonymous_use,
            inserted_at,
            updated_at
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
          RETURNING id
          """,
          [
            token_name,
            user.replicate_token,
            user.openai_token,
            user.gemini_token,
            user.vestaboard_panic_1_token,
            user.vestaboard_panic_2_token,
            user.vestaboard_panic_3_token,
            user.vestaboard_panic_4_token,
            # allow_anonymous_use
            false,
            DateTime.utc_now(),
            DateTime.utc_now()
          ]
        )

      # Create the join table entry
      Ecto.Adapters.SQL.query!(
        Panic.Repo,
        """
        INSERT INTO user_api_tokens (
          user_id,
          api_token_id,
          inserted_at,
          updated_at
        ) VALUES ($1, $2, $3, $4)
        """,
        [
          user.id,
          api_token_id,
          DateTime.utc_now(),
          DateTime.utc_now()
        ]
      )
    end)
  end

  def down do
    # This migration is not easily reversible because we'd need to decide
    # which APIToken to use if a user has multiple tokens.
    # For safety, we'll just raise an error.
    raise "This migration cannot be automatically reversed. Manual intervention required."
  end
end
