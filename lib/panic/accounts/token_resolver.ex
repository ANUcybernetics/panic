defmodule Panic.Accounts.TokenResolver do
  @moduledoc """
  Resolves API tokens for model invocations.

  Tokens are always resolved from the authenticated user's api_tokens,
  except for the Dummy platform which returns a static token for testing.
  """

  alias Panic.Platforms.Dummy

  @doc """
  Resolves a token for the given platform.

  ## Parameters
    - platform: The platform module (OpenAI, Replicate, Gemini, etc.)
    - user: The authenticated user (required unless Dummy platform)
      
  ## Returns
    - {:ok, token_string} if a valid token is found
    - {:error, reason} if no token is available
  """
  def resolve_token(platform, user) do
    # Dummy platform always returns a dummy token
    if platform == Dummy do
      {:ok, "dummy_token"}
    else
      resolve_user_token(platform, user)
    end
  end

  defp resolve_user_token(platform, user) do
    # Load user's api_tokens if not already loaded
    user = ensure_tokens_loaded(user)

    case find_platform_token(user.api_tokens, platform) do
      nil ->
        {:error, "User has no token for #{platform}"}

      token ->
        {:ok, token}
    end
  end

  defp ensure_tokens_loaded(user) do
    if Ash.Resource.loaded?(user, :api_tokens) do
      user
    else
      case Ash.load(user, :api_tokens, authorize?: false) do
        {:ok, loaded_user} -> loaded_user
        _ -> user
      end
    end
  end

  defp find_platform_token(api_tokens, platform) do
    field = platform_field(platform)

    api_tokens
    |> Enum.map(fn token -> Map.get(token, field) end)
    |> Enum.reject(&is_nil/1)
    |> List.first()
  end

  # Maps platform modules to their corresponding token field in ApiToken
  defp platform_field(Panic.Platforms.OpenAI), do: :openai_token
  defp platform_field(Panic.Platforms.Replicate), do: :replicate_token
  defp platform_field(Panic.Platforms.Gemini), do: :gemini_token
  defp platform_field(Dummy), do: nil
  defp platform_field(platform), do: raise("Unknown platform: #{inspect(platform)}")
end
