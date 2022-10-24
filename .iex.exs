alias Panic.{
  Repo,
  Accounts,
  Accounts.User,
  Accounts.UserSeeder,
  Accounts.UserNotifier,
  Accounts.UserQuery,
  Accounts.UserSeeder,
  Logs,
  Logs.Log,
  Slack,
  MailBluster,
  Orgs,
  Orgs.Invitation,
  Orgs.Membership
}

# Don't cut off inspects with "..."
IEx.configure(inspect: [limit: :infinity])

# Allow copy to clipboard
# eg:
#    iex(1)> Phoenix.Router.routes(PanicWeb.Router) |> Helpers.copy
#    :ok
defmodule Helpers do
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
