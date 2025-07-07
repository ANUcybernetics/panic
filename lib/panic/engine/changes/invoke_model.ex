defmodule Panic.Engine.Changes.InvokeModel do
  @moduledoc """
  Change module for invoking a model and handling the invocation process.

  This change:
  1. Performs the actual model invocation in a before_transaction hook to minimize DB contention
  2. Handles different platform authentication tokens
  3. Manages invocation success/failure states
  4. Sets the output and state based on the invocation result

  Important: API tokens are ALWAYS resolved from the network owner, not the current user.
  This ensures consistent token access regardless of who initiates the invocation
  (e.g., anonymous users accessing via QR code tokens).
  """
  use Ash.Resource.Change

  alias Panic.Accounts.TokenResolver

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
      case changeset do
        %{data: %{model: model_id, input: input}} ->
          # Pass the context which contains the actor
          perform_invocation(changeset, model_id, input, context)

        _ ->
          Ash.Changeset.add_error(changeset, "Invalid invocation data")
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

  defp perform_invocation(changeset, model_id, input, _context) do
    model = Panic.Model.by_id!(model_id)
    %Panic.Model{path: _path, invoke: invoke_fn, platform: platform} = model

    # Always use the network owner's tokens, not the current actor's
    # Load the network and its owner
    invocation = Ash.load!(changeset.data, [network: :user], authorize?: false)
    network_owner = invocation.network.user

    # Resolve token using the network owner
    token_result = TokenResolver.resolve_token(platform, network_owner)

    case token_result do
      {:ok, token} ->
        case invoke_fn.(model, input, token) do
          {:ok, output} ->
            changeset
            |> Ash.Changeset.put_context(:invocation_output, output)
            |> Ash.Changeset.put_context(:invocation_success, true)

          {:error, :nsfw} ->
            # NSFW error - retry with sanitized prompt
            retry_input = nsfw_retry_prompt(input)

            case invoke_fn.(model, retry_input, token) do
              {:ok, output} ->
                changeset
                |> Ash.Changeset.put_context(:invocation_output, output)
                |> Ash.Changeset.put_context(:invocation_success, true)

              {:error, message} ->
                changeset
                |> Ash.Changeset.add_error(message)
                |> Ash.Changeset.put_context(:invocation_success, false)
            end

          {:error, message} ->
            changeset
            |> Ash.Changeset.add_error(message)
            |> Ash.Changeset.put_context(:invocation_success, false)
        end

      {:error, reason} ->
        changeset
        |> Ash.Changeset.add_error(reason)
        |> Ash.Changeset.put_context(:invocation_success, false)
    end
  end

  defp nsfw_retry_prompt(_original_prompt) do
    "a wombat holding a sign that says 'whoops!'"
  end
end
