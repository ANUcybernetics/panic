defmodule Panic.Repo.Migrations.DeduplicateInvocations do
  use Ecto.Migration

  def up do
    # Delete duplicate invocations, keeping only the one with the smallest id
    # for each unique (network_id, run_number, sequence_number) combination
    execute """
    DELETE FROM invocations
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM invocations
      GROUP BY network_id, run_number, sequence_number
    )
    """
  end

  def down do
    # This migration is not reversible as we're deleting duplicate data
    # that shouldn't exist in the first place
    :ok
  end
end
