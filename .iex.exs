alias Panic.Accounts
alias Panic.Accounts.User
alias Panic.Engine.Invocation
alias Panic.Engine.Network
alias Panic.Model
alias Panic.Platforms.OpenAI
alias Panic.Platforms.Replicate
alias Panic.Platforms.Vestaboard
alias Panic.Repo

# Don't cut off inspects with "..."
IEx.configure(inspect: [limit: :infinity])

# Allow copy to clipboard
# eg:
#    iex(1)> Phoenix.Router.routes(PanicWeb.Router) |> Helpers.copy
#    :ok
defmodule Helpers do
  @moduledoc false
  def copy(term) do
    text =
      if is_binary(term) do
        term
      else
        inspect(term, limit: :infinity, pretty: true)
      end

    port = Port.open({:spawn, "pbcopy"}, [])
    true = Port.command(port, text)
    true = Port.close(port)

    :ok
  end
end
