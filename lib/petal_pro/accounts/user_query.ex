defmodule PetalPro.Accounts.UserQuery do
  @moduledoc """
  Functions that take an ecto query, alter it, then return it.
  Can be chained together to build up queries (along with QueryBuilder).
  """
  import Ecto.Query, warn: false
  alias PetalPro.Accounts.User

  def is_deleted(query, deleted? \\ true) do
    from u in query, where: u.is_deleted == ^deleted?
  end

  def is_suspended(query, suspended? \\ true) do
    from u in query, where: u.is_suspended == ^suspended?
  end

  def text_search(query \\ User, text_search)
  def text_search(query, nil), do: query
  def text_search(query, ""), do: query

  def text_search(query, text_search) do
    name_term = "%#{text_search}%"

    id_term =
      case Integer.parse(Util.trim(text_search)) do
        :error ->
          -1

        {num, _} ->
          num
      end

    from(
      u in query,
      where:
        ilike(u.name, ^name_term) or
          ilike(u.email, ^name_term) or
          u.last_signed_in_ip == ^text_search or
          u.id == ^id_term
    )
  end
end
