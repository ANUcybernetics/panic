defmodule Panic.Platforms.Vestaboard do
  @moduledoc false
  alias Panic.Model

  def send_text(%Model{path: _board_name}, text, token) do
    [method: :post, json: %{"text" => text}, headers: [{"X-Vestaboard-Read-Write-Key", token}]]
    |> req_new()
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

  def clear(model, token) do
    # this is a workaround, because the RW API doesn't allow blank messages
    send_text(model, "P!", token)
  end

  defp req_new(opts) do
    [
      base_url: "https://rw.vestaboard.com/",
      receive_timeout: 10_000
    ]
    |> Keyword.merge(opts)
    |> Req.new()
  end

  def token_for_model(%Model{path: board_name}) do
    Application.fetch_env!(:panic, :"vestaboard_#{board_name}_token")
  end
end
