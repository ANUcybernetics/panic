defmodule Panic.Platforms.OpenAI do
  @url "https://api.openai.com/v1/engines"
  @temperature 0.7
  @max_response_length 50
  # @recv_timeout 10_000

  @doc """
  Map of model info

  Keys are binaries of the form `platform:model-name`, and values are maps
  the following keys:

  - `name`: human readable name for the model
  - `description`: brief description of the model (supports markdown)
  - `input`: input type (either `:text`, `:image` or `:audio`)
  - `output`: output type (either `:text`, `:image` or `:audio`)
  """
  def all_model_info do
    %{
      "openai:text-davinci-003" => %{
        name: "GPT-3 Davinci",
        description: "",
        input: :text,
        output: :text
      },
      "openai:text-ada-001" => %{name: "GPT-3 Ada", description: "", input: :text, output: :text},
      "openai:davinci-instruct-beta" => %{
        name: "GPT-3 Davinci Instruct",
        description: "",
        input: :text,
        output: :text
      }
    }
  end

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

        if text == "" do
          {:error, :blank_output}
        else
          {:ok, text}
        end
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
