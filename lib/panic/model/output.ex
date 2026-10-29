defmodule Panic.Model.Output do
  @moduledoc """
  Parsers that pick a model's output out of its platform's response, for a
  model's `output` field (see `Panic.Model`). Each returns `{:ok, output}`, or
  `{:error, reason}` for a response it doesn't recognise, so a model that
  changes its output format fails the invocation rather than passing the
  response along as its output.
  """

  @doc "The response as it is, for platforms that already return the output."
  def as_is(response), do: {:ok, response}

  @doc "Text, which models may stream as a list of chunks, trimmed."
  def text(response) when is_binary(response) or is_list(response) do
    case response |> List.wrap() |> Enum.join() |> String.trim() do
      "" -> {:error, "Model returned no text"}
      text -> {:ok, text}
    end
  end

  def text(response), do: unexpected(response)

  @doc "A URL, or the first of a list of them."
  def first_url(url) when is_binary(url) and url != "", do: {:ok, url}
  def first_url([url | _]) when is_binary(url) and url != "", do: {:ok, url}
  def first_url(response), do: unexpected(response)

  @doc "A parser for a string at `key` of a map."
  def key(key) do
    fn
      %{^key => value} when is_binary(value) and value != "" -> {:ok, value}
      response -> unexpected(response)
    end
  end

  defp unexpected(response), do: {:error, "Unexpected model output: #{inspect(response, limit: 5)}"}
end
