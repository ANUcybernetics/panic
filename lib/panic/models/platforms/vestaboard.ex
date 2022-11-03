defmodule Panic.Models.Platforms.Vestaboard do
  @url "https://platform.vestaboard.com"

  def list_subscriptions(board_name) do
    url = "#{@url}/subscriptions"

    case HTTPoison.get(url, headers(board_name)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)
    end
  end

  def send_text(board_name, text) do
    url = "#{@url}/subscriptions/#{subscription_id(board_name)}/message"

    {:ok, request_body} = Jason.encode(%{text: text})

    case HTTPoison.post(url, request_body, headers(board_name)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)
    end
  end

  defp board_id(board_name) do
    %{
      panic_1: "ba16996e-154f-4f31-83b7-ae0a8f13ecaf",
      panic_2: "26241875-af6f-44dc-916a-4895b46eda57",
      panic_3: "c3def357-b70c-45df-ba68-1bf40ff24400"
    }
    |> Map.get(board_name)
  end

  defp subscription_id(board_name) do
    %{
      panic_1: "d7b69bfe-1d60-4e8d-a36f-5ecb78fa70a0",
      panic_2: "24968321-770c-4b14-9e20-21e82a60a81c",
      panic_3: ""
    }
    |> Map.get(board_name)
  end

  defp headers(board_name) do
    api_key =
      %{
        panic_1: "880d3547-6cef-4f36-a81b-2ab0b7120505",
        panic_2: "9ee492bc-ec91-4df4-b89f-c0bf55061268",
        panic_3: "d0c959c8-22ef-46fc-b4d7-286280501a3c"
      }
      |> Map.get(board_name)

    api_secret =
      %{
        panic_1: Application.fetch_env!(:panic, :vestaboard_api_secret_1),
        panic_2: Application.fetch_env!(:panic, :vestaboard_api_secret_2),
        panic_3: Application.fetch_env!(:panic, :vestaboard_api_secret_3)
      }
      |> Map.get(board_name)

    %{
      "X-Vestaboard-Api-Key" => api_key,
      "X-Vestaboard-Api-Secret" => api_secret,
      "Content-Type" => "application/json"
    }
  end
end
