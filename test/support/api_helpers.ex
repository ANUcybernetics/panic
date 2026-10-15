defmodule PanicWeb.ApiHelpers do
  @moduledoc """
  Helpers for JSON API tests: an admin with an API key, conns that carry it,
  and JSON:API request bodies.
  """
  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Plug.Conn

  @doc "An admin user and the plaintext of a fresh API key for them."
  def admin_with_api_key do
    admin =
      Panic.Fixtures.user()
      |> Ash.Changeset.for_update(:set_admin, %{admin: true})
      |> Ash.update!(authorize?: false)

    {admin, api_key_for(admin)}
  end

  def api_key_for(user, attrs \\ %{}) do
    Panic.Accounts.ApiKey
    |> Ash.Changeset.for_create(:create, Map.merge(%{name: "test key"}, attrs), actor: user)
    |> Ash.create!(authorize?: false)
    |> Map.fetch!(:__metadata__)
    |> Map.fetch!(:plaintext_api_key)
  end

  def api_conn(api_key) do
    build_conn()
    |> put_req_header("authorization", "Bearer " <> api_key)
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("content-type", "application/vnd.api+json")
  end

  @doc "A JSON:API request body for `type` with the given attributes."
  def body(type, attributes \\ %{}) do
    Jason.encode!(%{data: %{type: type, attributes: attributes}})
  end

  @doc "Asserts the response status and returns the decoded body."
  def json(conn, status) do
    assert conn.status == status, "expected #{status}, got #{conn.status}: #{conn.resp_body}"
    Jason.decode!(conn.resp_body)
  end
end
