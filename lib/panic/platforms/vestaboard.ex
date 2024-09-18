defmodule Panic.Platforms.Vestaboard do
  @moduledoc false
  def send_text(board_name, text) do
    board_name
    |> req_new(method: :post, json: %{"text" => text})
    |> Req.request()
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"id" => id}}} ->
        {:ok, id}

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

  defp req_new(board_name, opts) do
    token = Application.fetch_env!(:panic, :"vestaboard_api_token_#{to_string(board_name)}")
    headers = [{"X-Vestaboard-Read-Write-Key", token}]

    [
      base_url: "https://rw.vestaboard.com/",
      receive_timeout: 10_000,
      headers: headers
    ]
    |> Keyword.merge(opts)
    |> Req.new()
  end
end
