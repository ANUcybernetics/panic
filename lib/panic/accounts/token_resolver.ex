defmodule Panic.Accounts.TokenResolver do
  @moduledoc """
  Resolves API tokens for model invocations.
  
  For authenticated requests, uses tokens from the user's api_tokens.
  For anonymous requests, finds any token marked with allow_anonymous_use: true.
  """
  
  alias Panic.Accounts.APIToken
  import Ash.Query
  
  @doc """
  Resolves a token for the given platform.
  
  ## Parameters
    - platform: The platform module (OpenAI, Replicate, Gemini, etc.)
    - opts: Options including:
      - actor: The authenticated user (optional)
      - anonymous: Boolean indicating anonymous access (optional)
      
  ## Returns
    - {:ok, token_string} if a valid token is found
    - {:error, reason} if no token is available
  """
  def resolve_token(platform, opts \\ []) do
    # Dummy platform always returns a dummy token
    if platform == Panic.Platforms.Dummy do
      {:ok, "dummy_token"}
    else
      actor = Keyword.get(opts, :actor)
      anonymous = Keyword.get(opts, :anonymous, false)
      
      cond do
        # Authenticated user - use their tokens
        actor && !anonymous ->
          resolve_user_token(platform, actor)
          
        # Anonymous access - find any token with allow_anonymous_use
        anonymous || is_nil(actor) ->
          resolve_anonymous_token(platform)
          
        # Should not reach here
        true ->
          {:error, "Invalid token resolution state"}
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
  
  defp resolve_anonymous_token(platform) do
    # Query for tokens that allow anonymous use
    query = 
      APIToken
      |> filter(allow_anonymous_use == true)
      |> filter(not is_nil(^platform_field(platform)))
      |> sort(updated_at: :desc)
      |> limit(1)
    
    case Ash.read_one(query, authorize?: false) do
      {:ok, nil} ->
        {:error, "No anonymous token available for #{platform}"}
        
      {:ok, api_token} ->
        token_value = Map.get(api_token, platform_field(platform))
        {:ok, token_value}
        
      {:error, error} ->
        {:error, "Failed to query anonymous tokens: #{inspect(error)}"}
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
      Panic.Platforms.Dummy -> nil
      _ -> raise "Unknown platform: #{inspect(platform)}"
    end
  end
end