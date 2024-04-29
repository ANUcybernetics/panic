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

      {:ok, %HTTPoison.Response{status_code: 400}} ->
        {:ok, :bad_request}

      {:ok, %HTTPoison.Response{status_code: 405}} ->
        {:ok, :bad_request}

      {:ok, %HTTPoison.Response{status_code: 503}} ->
        {:ok, :too_many_requests}
    end
  end

  def clear_all(board_ids) do
    board_ids |> Enum.each(&send_text(&1, ""))
  end

  defp api_key(board_name) do
    Application.fetch_env!(:panic, :"vestaboard_api_token_#{to_string(board_name)}")
  end
end
