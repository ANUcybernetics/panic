defmodule Panic.Platforms.Vestaboard do
  @moduledoc false
  alias Panic.Model

  require Logger

  def send_text(%Model{path: board_name}, text, token) do
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

  def token_for_model!(%Model{path: board_name}, user) do
    Map.fetch!(user, :"vestaboard_#{board_name}_token")
  end
end
