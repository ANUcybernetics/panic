defmodule PanicWeb.ApiAuth do
  @moduledoc """
  Authentication for the JSON API: requests need an admin's API key as a
  bearer token (`Authorization: Bearer panic_...`). Admins mint keys on the
  admin page.
  """
  import Plug.Conn

  @doc "`on_error` callback for `AshAuthentication.Strategy.ApiKey.Plug`."
  def unauthorized(conn, _error) do
    send_error(conn, 401, "Unauthorized", "a valid API key is required")
  end

  @doc """
  Plug that answers a blank bearer token (`Authorization: Bearer `) with 401.
  It must run before `AshAuthentication.Strategy.ApiKey.Plug`, which crashes
  on one rather than rejecting it.
  """
  def reject_blank_bearer(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer" <> token] ->
        if String.trim(token) == "", do: unauthorized(conn, :missing_api_key), else: conn

      _ ->
        conn
    end
  end

  @doc """
  Plug that halts unless the authenticated user is an admin. The OpenAPI spec
  is public so the Swagger UI (`/api/swaggerui`) can load it.
  """
  def require_admin(%{method: "GET", path_info: ["api", "open_api"]} = conn, _opts), do: conn

  def require_admin(conn, _opts) do
    case conn.assigns[:current_user] do
      %{admin: true} -> conn
      nil -> unauthorized(conn, :missing_api_key)
      _user -> send_error(conn, 403, "Forbidden", "the API is only available to admins")
    end
  end

  defp send_error(conn, status, title, detail) do
    body = %{errors: [%{status: to_string(status), title: title, detail: detail}]}

    conn
    |> put_resp_content_type("application/vnd.api+json")
    |> send_resp(status, Jason.encode!(body))
    |> halt()
  end
end
