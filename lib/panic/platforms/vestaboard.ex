defmodule Panic.Models.Platforms.Vestaboard do
  @url "https://rw.vestaboard.com/"

  def send_text(board_name, text) do
    request_body = Jason.encode!(%{"text" => text})

    headers = [
      {"X-Vestaboard-Read-Write-Key", api_key(board_name)},
      {"Content-Type", "application/json"}
    ]

    case Req.post(@url, body: request_body, headers: headers) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %Req.Response{status: status_code}} when status_code in [400, 405] ->
        {:error, :bad_request}

      {:ok, %Req.Response{status: 304}} ->
        {:error, :not_modified}

      {:ok, %Req.Response{status: 503}} ->
        {:error, :too_many_requests}
    end
  end

  def clear(board_name) do
    # this is a workaround, because the RW API doesn't allow blank messages
    send_text(board_name, "blank")
  end

  defp api_key(board_name) do
    Application.fetch_env!(:panic, :"vestaboard_api_token_#{to_string(board_name)}")
  end
end
