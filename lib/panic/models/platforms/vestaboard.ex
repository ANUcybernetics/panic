defmodule Panic.Models.Platforms.Vestaboard do
  @url "https://rw.vestaboard.com/"

  def send_text(board_name, text) do
    request_body = Jason.encode!(%{"text" => text})

    headers = [
      {"X-Vestaboard-Read-Write-Key", api_key(board_name)},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.post(@url, request_body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code in [400, 405] ->
        {:error, :bad_request}

      {:ok, %HTTPoison.Response{status_code: 304}} ->
        {:error, :not_modified}

      {:ok, %HTTPoison.Response{status_code: 503}} ->
        {:error, :too_many_requests}
    end
  end

  def clear_all(board_names) do
    # this is a workaround, because the RW API doesn't allow blank messages
    board_names |> Enum.each(&send_text(&1, "blank"))
  end

  defp api_key(board_name) do
    Application.fetch_env!(:panic, :"vestaboard_api_token_#{to_string(board_name)}")
  end
end
