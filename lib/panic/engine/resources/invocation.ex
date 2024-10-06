defmodule Panic.Engine.Invocation do
  @moduledoc """
  A resource representing a specific "inference" run for a single model

  The resource includes both the input (prompt) an the output (prediction)
  along with some other metadata.
  """
  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias Panic.Engine.Network
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate
  alias Panic.Platforms.Vestaboard

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

    attribute :state, :atom do
      constraints one_of: [:ready, :invoking, :completed, :failed]
      allow_nil? false
      default :ready
    end

    attribute :model, {:array, :string}, allow_nil?: false
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
    defaults [:read, :destroy]

    # TODO could this be a calculation/aggregate
    read :most_recent do
      argument :network_id, :integer
      filter expr(network_id == ^arg(:network_id))
      prepare build(sort: [updated_at: :desc], limit: 1)
      get? true
    end

    read :list_run do
      argument :network_id, :integer, allow_nil?: false
      argument :run_number, :integer, allow_nil?: false
      prepare build(sort: [sequence_number: :asc])
      filter expr(network_id == ^arg(:network_id) and run_number == ^arg(:run_number))
    end

    read :current_run do
      argument :network_id, :integer, allow_nil?: false
      argument :limit, :integer, default: 100
      prepare build(sort: [sequence_number: :asc], limit: arg(:limit))

      # FIXME make sure this is done with a db index (perhaps via an identity?) for performance reasons
      filter expr(
               network_id == ^arg(:network_id) and
                 run_number == fragment("SELECT MAX(run_number) FROM invocations WHERE network_id = ?", ^arg(:network_id)) and
                 state == :completed
             )
    end

    # maybe "prepare"?
    create :prepare_first do
      accept [:input]

      argument :network, :struct do
        constraints instance_of: Network
        allow_nil? false
      end

      change set_attribute(:sequence_number, 0)

      change fn changeset, _context ->
        case Ash.Changeset.fetch_argument(changeset, :network) do
          {:ok, network} ->
            network_length = Enum.count(network.models)

            case network.models do
              [] ->
                Ash.Changeset.add_error(changeset, "No models in network")

              [model | _] ->
                changeset
                |> Ash.Changeset.force_change_attribute(:model, model)
                |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)
            end

          :error ->
            Ash.Changeset.add_error(changeset, "missing :network argument")
        end
      end

      # for "first runs", we need to wait until the invocation is created in the db (so it gets an id)
      # and then set the :run_number field to that value (hence this "update record in after action hook" thing)
      change after_action(fn changeset, invocation, _context ->
               invocation
               |> Ash.Changeset.for_update(:set_run_number, %{run_number: invocation.id})
               |> Ash.update!(authorize?: false)
               |> then(&{:ok, &1})
             end)
    end

    create :prepare_next do
      argument :previous_invocation, :struct do
        constraints instance_of: __MODULE__
        allow_nil? false
      end

      change fn changeset, context ->
        {:ok, previous_invocation} = Ash.Changeset.fetch_argument(changeset, :previous_invocation)

        %{
          network: %{models: models} = network,
          run_number: run_number,
          sequence_number: prev_sequence_number,
          output: prev_output
        } = Ash.load!(previous_invocation, :network, actor: context.actor)

        model_index = Integer.mod(prev_sequence_number + 1, Enum.count(models))
        model = Enum.at(models, model_index)

        changeset
        |> Ash.Changeset.force_change_attribute(:model, model)
        |> Ash.Changeset.force_change_attribute(:run_number, run_number)
        |> Ash.Changeset.force_change_attribute(:sequence_number, prev_sequence_number + 1)
        |> Ash.Changeset.force_change_attribute(:input, prev_output)
        |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)
      end
    end

    update :set_run_number do
      accept [:run_number]
    end

    update :update_output do
      accept [:output]
    end

    update :about_to_invoke do
      change set_attribute(:state, :invoking)
    end

    update :invoke do
      change fn
        changeset, context ->
          case {changeset, context} do
            {_, %{actor: nil}} ->
              Ash.Changeset.add_error(
                changeset,
                "actor must be present (to obtain API token)"
              )

            {%{data: %{model: models_and_vestaboards, input: input}}, %{actor: user}} ->
              [model_id | vestaboards] = Enum.reverse(models_and_vestaboards)
              model = Panic.Model.by_id!(model_id)
              %Panic.Model{path: path, invoke: invoke_fn, platform: platform} = model

              token =
                case platform do
                  OpenAI -> context.actor.openai_token
                  Replicate -> context.actor.replicate_token
                end

              if token do
                # invoking returning, put the output on the vestaboards as a side effect
                if vestaboards != [] do
                  Enum.each(vestaboards, fn vestaboard_id ->
                    vestaboard_model = Panic.Model.by_id!(vestaboard_id)
                    vestaboard_token = Vestaboard.token_for_model!(vestaboard_model, user)
                    Vestaboard.send_text(vestaboard_model, input, vestaboard_token)
                  end)

                  # give the Vestaboards some time to display the text
                  Process.sleep(5_000)
                end

                case invoke_fn.(model, input, token) do
                  {:ok, output} ->
                    changeset
                    |> Ash.Changeset.force_change_attribute(:output, output)
                    |> Ash.Changeset.force_change_attribute(:state, :completed)

                  {:error, :nsfw} ->
                    changeset
                    |> Ash.Changeset.force_change_attribute(
                      :output,
                      "https://fly.storage.tigris.dev/panic-invocation-outputs/nsfw-sign.png"
                    )
                    |> Ash.Changeset.force_change_attribute(:state, :completed)

                  {:error, message} ->
                    changeset
                    |> Ash.Changeset.add_error(message)
                    |> Ash.Changeset.force_change_attribute(:state, :failed)
                end
              else
                changeset
                |> Ash.Changeset.add_error("user has no auth token for #{platform}")
                |> Ash.Changeset.force_change_attribute(:state, :failed)
              end
          end
      end

      change set_attribute(:state, :completed)
    end

    update :cancel do
      change set_attribute(:state, :failed)
    end
  end

  relationships do
    belongs_to :network, Network, allow_nil?: false
  end

  policies do
    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if relates_to_actor_via([:network, :user])
    end

    policy action(:set_run_number) do
      authorize_if always()
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via([:network, :user])
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:network, :user])
    end
  end

  pub_sub do
    module PanicWeb.Endpoint
    prefix "invocation"
    publish_all :update, [:network_id]
  end
end
