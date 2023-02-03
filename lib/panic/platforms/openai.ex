defmodule Panic.Platforms.OpenAI do
  @url "https://api.openai.com/v1/engines"
  @temperature 0.7
  @max_response_length 50
  # @recv_timeout 10_000

  def list_engines(user) do
    Finch.build(:get, @url, headers(user))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        %{"data" => data} = Jason.decode!(response_body)
        data

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create(model, prompt, user)
      when model in ["text-davinci-003", "text-ada-001", "davinci-instruct-beta"] do
    request_body = %{
      prompt: prompt,
      max_tokens: @max_response_length,
      temperature: @temperature
    }

    Finch.build(:post, "#{@url}/#{model}/completions", headers(user), Jason.encode!(request_body))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        %{"choices" => [%{"text" => text} | _choices]} = Jason.decode!(response_body)

        if text == "", do: "GPT-3 could not complete the prompt.", else: String.downcase(text)
    end
  end

  defp headers(user) do
    %Panic.Accounts.APIToken{token: token} = Panic.Accounts.get_api_token!(user, "OpenAI")

    %{
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end
end
