defmodule Panic.Models.Platforms.Vestaboard do
  @url "https://platform.vestaboard.com"

  def board_id(board_name) do
    %{
      panic_1: "ba16996e-154f-4f31-83b7-ae0a8f13ecaf",
      panic_2: "26241875-af6f-44dc-916a-4895b46eda57",
      panic_3: "c3def357-b70c-45df-ba68-1bf40ff24400"
    }
    |> Map.get(board_name)
  end

  def subscription_id(board_name) do
    %{
      panic_1: "d7b69bfe-1d60-4e8d-a36f-5ecb78fa70a0"
    }
    |> Map.get(board_name)
  end

  def list_subscriptions() do
    url = "#{@url}/subscriptions"

    case HTTPoison.get(url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)
    end
  end

  def send_text(board_name, text) do
    url = "#{@url}/subscriptions/#{subscription_id(board_name)}/message"

    {:ok, request_body} = Jason.encode(%{text: text})

    case HTTPoison.post(url, request_body, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)
    end
  end

  defp headers do
    api_key = Application.fetch_env!(:panic, :vestaboard_api_key)
    api_secret = Application.fetch_env!(:panic, :vestaboard_api_secret)

    %{
      "X-Vestaboard-Api-Key" => api_key,
      "X-Vestaboard-Api-Secret" => api_secret,
      "Content-Type" => "application/json"
    }
  end
end
