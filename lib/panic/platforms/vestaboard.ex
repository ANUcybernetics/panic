defmodule Panic.Platforms.Vestaboard do
  @moduledoc false

  require Logger

  def send_text(text, token, board_name \\ "unknown") do
    # Check if vestaboard is disabled via application config (for tests)
    if Application.get_env(:panic, :disable_vestaboard, false) do
      {:ok, "mock-vestaboard-id-#{System.unique_integer([:positive])}"}
    else
      [method: :post, json: %{"text" => text}, headers: [{"X-Vestaboard-Read-Write-Key", token}]]
      |> req_new()
      |> Req.request()
      |> case do
        {:ok, %Req.Response{status: 200, body: %{"id" => id}}} ->
          {:ok, id}

        {:ok, %Req.Response{status: status_code}} when status_code in 400..499 ->
          Logger.warning("Vestaboard API (#{board_name}): client error #{status_code}")
          {:error, :client_error}

        {:ok, %Req.Response{status: 304}} ->
          Logger.warning("Vestaboard API (#{board_name}): not modified 304")
          {:error, :not_modified}

        {:ok, %Req.Response{status: 503}} ->
          Logger.warning("Vestaboard API (#{board_name}): too many requests 503")
          {:error, :too_many_requests}

        {:error, reason} ->
          Logger.warning("Vestaboard API (#{board_name}): unknown error")
          {:error, reason}
      end
    end
  end

  def clear(token, board_name \\ "unknown") do
    # this is a workaround, because the RW API doesn't allow blank messages
    send_text("P!", token, board_name)
  end

  defp req_new(opts) do
    [
      base_url: "https://rw.vestaboard.com/",
      receive_timeout: 10_000
    ]
    |> Keyword.merge(opts)
    |> Req.new()
  end

  def token_for_board!(board_name, user) do
    # Return mock token in test environment
    if Application.get_env(:panic, :disable_vestaboard, false) do
      "mock-vestaboard-token"
    else
      # Ensure user has api_tokens loaded
      user =
        if Ash.Resource.loaded?(user, :api_tokens) do
          user
        else
          case Ash.load(user, :api_tokens, authorize?: false) do
            {:ok, loaded_user} -> loaded_user
            _ -> user
          end
        end

      field = :"vestaboard_#{board_name}_token"

      # Look for the token in api_tokens
      token =
        user.api_tokens
        |> Enum.map(fn api_token -> Map.get(api_token, field) end)
        |> Enum.reject(&is_nil/1)
        |> List.first()

      if token do
        token
      else
        raise "User has no Vestaboard token for board: #{board_name}"
      end
    end
  end
end
