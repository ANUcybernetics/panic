defmodule Panic.Models.Platforms.Vestaboard do
  @url "https://platform.vestaboard.com"

  def list_subscriptions(board_name, tokens) do
    Finch.build(:get, "#{@url}/subscriptions", headers(board_name, tokens))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        Jason.decode!(response_body)
    end
  end

  def send_text(board_name, text, tokens) do
    url = "#{@url}/subscriptions/#{subscription_id(board_name, tokens)}/message"

    Finch.build(:post, url, headers(board_name, tokens), Jason.encode!(%{text: text}))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        Jason.decode(response_body)

      {:ok, %Finch.Response{status: 503}} ->
        # this isn't *really* ok, but hopefully we can ignore it
        {:ok, :too_many_requests}
    end
  end

  def clear_all(board_ids, tokens) do
    board_ids |> Enum.each(&send_text(&1, "", tokens))
  end

  ## NOTE: Vestaboard API requires heaps of info: board & subscription IDs,
  ## plus an API key *and* an API secret, and we (somewhat jankily) store them
  ## in one DB field using `:` separators, because I *think* the tokens
  ## themselves will never contain a `:`
  defp subscription_id(board_name, tokens) do
    %{^board_name => token} = tokens
    [_board_id, subscription_id, _api_key, _api_secret] = String.split(token, ":")
    subscription_id
  end

  defp headers(board_name, tokens) do
    ## NOTE: Vestaboard API requires heaps of info: board & subscription IDs,
    ## plus an API key *and* an API secret, and we (somewhat jankily) store them
    ## in one DB field using `:` separators, because I *think* the tokens
    ## themselves will never contain a `:`
    %{^board_name => token} = tokens
    [_board_id, _subscription_id, api_key, api_secret] = String.split(token, ":")

    %{
      "X-Vestaboard-Api-Key" => api_key,
      "X-Vestaboard-Api-Secret" => api_secret,
      "Content-Type" => "application/json"
    }
  end
end
