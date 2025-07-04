defmodule Panic.Accounts.TokenResolver do
  @moduledoc """
  Resolves API tokens for model invocations.

  Uses tokens from the user's api_tokens.
  """

  alias Panic.Platforms.Dummy

  @doc """
  Resolves a token for the given platform.

  ## Parameters
    - platform: The platform module (OpenAI, Replicate, Gemini, etc.)
    - opts: Options including:
      - actor: The authenticated user (required unless Dummy platform)
      
  ## Returns
    - {:ok, token_string} if a valid token is found
    - {:error, reason} if no token is available
  """
  def resolve_token(platform, opts \\ []) do
    # Dummy platform always returns a dummy token
    if platform == Dummy do
      {:ok, "dummy_token"}
    else
      actor = Keyword.get(opts, :actor)

      if actor do
        resolve_user_token(platform, actor)
      else
        {:error, "No user provided for token resolution"}
      end
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

  defp platform_field(platform) do
    case platform do
      Panic.Platforms.OpenAI -> :openai_token
      Panic.Platforms.Replicate -> :replicate_token
      Panic.Platforms.Gemini -> :gemini_token
      # Dummy platform doesn't need a real token
      Dummy -> nil
      _ -> raise "Unknown platform: #{inspect(platform)}"
    end
  end
end
