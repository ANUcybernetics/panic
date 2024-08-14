defmodule Panic.Engine.Network do
  @moduledoc """
  A Network represents a specific network (i.e. cyclic graph) of models.
  """
  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "networks"
    repo Panic.Repo
  end

  attributes do
    integer_primary_key :id

    # attribute :owner
    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :models, {:array, :module} do
      default []
      allow_nil? false
      # TODO validate that the module conforms to the Model behaviour
    end

    attribute :state, :atom do
      default :stopped

      # `:starting` represents the initial "uninterruptible" period
      constraints one_of: [:starting, :running, :paused, :stopped]
      allow_nil? false
    end

    attribute :slug, :string
    create_timestamp :inserted_at
    update_timestamp :updated_at
    # attribute :schedule
    # attribute :backoff
  end

  actions do
    defaults [:destroy]

    create :create do
      accept [:name, :description]
      set_attribute(:models, [])
      change relate_actor(:user)
    end

    read :by_id do
      get_by :id
      primary? true
    end

    update :append_model do
      # describe("Append a model to the end of the list of models")
      argument :model, Ash.Type.Module, allow_nil?: false

      change fn changeset, _ ->
        models = changeset.data.models ++ [Ash.Changeset.get_argument(changeset, :model)]

        case validate_model_io_types(models) do
          :ok ->
            Ash.Changeset.change_attribute(changeset, :models, models)

          {:error, message} ->
            Ash.Changeset.add_error(changeset, field: :models, message: message)
        end
      end
    end

    # update :drop_model
    # update :swap_model
    # action :start_run
    # read :statistics
    # read :state
    # update :set_state
    # create :duplicate # duplicate the network

    update :set_state do
      argument :state, :atom, allow_nil?: false
      change set_attribute(:state, arg(:state))
    end
  end

  relationships do
    belongs_to :user, Panic.Accounts.User, allow_nil?: false
  end

  def validate_model_io_types(models) do
    # validate that each "interface" matches
    models
    |> Enum.map(&{&1.fetch!(:name), &1.fetch!(:input_type), &1.fetch!(:output_type)})
    # hack to ensure first input is :text
    |> List.insert_at(0, {"Initial input", nil, :text})
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce([], fn [{name_1, _, output_type}, {name_2, input_type, _}], errors ->
      if output_type == input_type do
        errors
      else
        [
          "#{name_1} output (#{output_type}) does not match #{name_2} input (#{input_type})"
          | errors
        ]
      end
    end)
    |> case do
      [] ->
        :ok

      error_string ->
        {:error, Enum.join(error_string, ", ")}
    end
  end
end
