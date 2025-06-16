defmodule Panic.Engine.Changes.InvokeModel do
  @moduledoc """
  Change module for invoking a model and handling the invocation process.

  This change:
  1. Performs the actual model invocation in a before_transaction hook to minimize DB contention
  2. Handles different platform authentication tokens
  3. Manages invocation success/failure states
  4. Sets the output and state based on the invocation result
  """
  use Ash.Resource.Change

  alias Panic.Platforms.Dummy
  alias Panic.Platforms.Gemini
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> add_before_transaction_hook(context)
    |> add_before_action_hook()
  end

  defp add_before_transaction_hook(changeset, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      case {changeset, context} do
        {_, %{actor: nil}} ->
          Ash.Changeset.add_error(
            changeset,
            "actor must be present (to obtain API token)"
          )

        {%{data: %{model: model_id, input: input}}, %{actor: user}} ->
          perform_invocation(changeset, model_id, input, user)
      end
    end)
  end

  defp add_before_action_hook(changeset) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      # Apply the invocation results from context
      if changeset.context[:invocation_success] do
        output = changeset.context[:invocation_output]

        changeset
        |> Ash.Changeset.force_change_attribute(:output, output)
        |> Ash.Changeset.force_change_attribute(:state, :completed)
      else
        Ash.Changeset.force_change_attribute(changeset, :state, :failed)
      end
    end)
  end

  defp perform_invocation(changeset, model_id, input, user) do
    model = Panic.Model.by_id!(model_id)
    %Panic.Model{path: _path, invoke: invoke_fn, platform: platform} = model

    token = get_token_for_platform(platform, user)

    if token do
      case invoke_fn.(model, input, token) do
        {:ok, output} ->
          changeset
          |> Ash.Changeset.put_context(:invocation_output, output)
          |> Ash.Changeset.put_context(:invocation_success, true)

        {:error, :nsfw} ->
          changeset
          |> Ash.Changeset.put_context(
            :invocation_output,
            "https://fly.storage.tigris.dev/panic-invocation-outputs/nsfw-placeholder.webp"
          )
          |> Ash.Changeset.put_context(:invocation_success, true)

        {:error, message} ->
          changeset
          |> Ash.Changeset.add_error(message)
          |> Ash.Changeset.put_context(:invocation_success, false)
      end
    else
      changeset
      |> Ash.Changeset.add_error("user has no auth token for #{platform}")
      |> Ash.Changeset.put_context(:invocation_success, false)
    end
  end

  defp get_token_for_platform(platform, user) do
    case platform do
      OpenAI -> user.openai_token
      Replicate -> user.replicate_token
      Gemini -> user.gemini_token
      Dummy -> "dummy_token"
    end
  end
end
