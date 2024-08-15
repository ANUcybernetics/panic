defmodule Panic.Engine.Invocation do
  @moduledoc """
  A resource representing a specific "inference" run for a single model

  The resource includes both the input (prompt) an the output (prediction)
  along with some other metadata.
  """
  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "invocations"
    repo Panic.Repo
  end

  resource do
    plural_name :invocations
  end

  attributes do
    integer_primary_key :id

    attribute :input, :string, allow_nil?: false
    attribute :model, :module, allow_nil?: false
    attribute :metadata, :map, allow_nil?: false, default: %{}
    attribute :output, :string

    attribute :sequence_number, :integer do
      constraints min: 0
      allow_nil? false
    end

    attribute :run_number, :integer do
      constraints min: 0
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    read :by_id, get_by: :id

    read :most_recent do
      argument :network_id, :integer
      argument :limit, :integer
      filter expr(network_id == ^arg(:network_id))
      prepare build(sort: [updated_at: :desc], limit: arg(:limit))
    end

    read :all_in_run do
      argument :network_id, :integer
      argument :run_number, :integer
      prepare build(sort: [sequence_number: :asc])
      filter expr(network_id == ^arg(:network_id) and run_number == ^arg(:run_number))
    end

    # maybe "prepare"?
    create :prepare_first do
      accept [:input]

      argument :network, :struct do
        constraints instance_of: Panic.Engine.Network
        allow_nil? false
      end

      change set_attribute(:sequence_number, 0)

      change fn changeset, _context ->
        {:ok, network} = Ash.Changeset.fetch_argument(changeset, :network)
        network_length = Enum.count(network.models)

        if network_length == 0 do
          Ash.Changeset.add_error(changeset, "No models in network")
        else
          changeset
          |> Ash.Changeset.change_attribute(:model, List.first(network.models))
          |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)
        end
      end

      # for "first runs", we need to wait until the invocation is created in the db (so it gets an id)
      # and then set the :run_number field to that value (hence this "update record in after action hook" thing)
      change after_action(fn changeset, invocation, _context ->
               invocation
               |> Ash.Changeset.for_update(:set_run_number, %{run_number: invocation.id})
               |> Ash.update!()
               |> then(&{:ok, &1})
             end)
    end

    update :set_run_number do
      accept [:run_number]
    end

    create :prepare_next do
      argument :previous_invocation, :struct do
        constraints instance_of: __MODULE__
        allow_nil? false
      end

      change fn changeset, _context ->
        {:ok, previous_invocation} = Ash.Changeset.fetch_argument(changeset, :previous_invocation)

        %{
          network: %{models: models} = network,
          run_number: run_number,
          sequence_number: prev_sequence_number,
          output: prev_output
        } = previous_invocation

        model_index = Integer.mod(prev_sequence_number + 1, Enum.count(models))
        model = Enum.at(models, model_index)

        changeset
        |> Ash.Changeset.change_attribute(:model, model)
        |> Ash.Changeset.change_attribute(:run_number, run_number)
        |> Ash.Changeset.change_attribute(:sequence_number, prev_sequence_number + 1)
        |> Ash.Changeset.change_attribute(:input, prev_output)
        |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)
      end
    end

    update :invoke do
      change fn
        changeset, _context ->
          %{model: model, input: input} = changeset.data

          case model.invoke(input) do
            {:ok, output} ->
              Ash.Changeset.change_attribute(changeset, :output, output)

            {:error, message} ->
              Ash.Changeset.add_error(changeset, message)
          end
      end
    end
  end

  relationships do
    belongs_to :network, Panic.Engine.Network, allow_nil?: false
  end
end
