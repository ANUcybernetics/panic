defmodule PanicWeb.Api.AuthTest do
  use PanicWeb.ConnCase, async: false

  import PanicWeb.ApiHelpers

  test "an admin's key gets in" do
    {_admin, key} = admin_with_api_key()
    assert %{"data" => []} = key |> api_conn() |> get("/api/networks") |> json(200)
  end

  test "requests without a key are unauthorized" do
    assert %{"errors" => [%{"status" => "401"}]} =
             build_conn() |> get("/api/networks") |> json(401)
  end

  test "unknown keys and non-bearer headers are unauthorized" do
    assert "panic_notarealkey" |> api_conn() |> get("/api/networks") |> json(401)

    conn = build_conn() |> put_req_header("authorization", "Basic abc") |> get("/api/networks")
    assert json(conn, 401)
  end

  test "an empty bearer token is unauthorized" do
    for header <- ["Bearer ", "Bearer", "Bearer   "] do
      conn = build_conn() |> put_req_header("authorization", header) |> get("/api/networks")
      assert json(conn, 401), "expected 401 for #{inspect(header)}"
    end
  end

  test "expired keys are unauthorized" do
    {admin, _key} = admin_with_api_key()
    expired = api_key_for(admin, %{expires_at: DateTime.shift(DateTime.utc_now(), minute: -1)})

    assert expired |> api_conn() |> get("/api/networks") |> json(401)
  end

  test "keys stop working once revoked" do
    {admin, key} = admin_with_api_key()
    [api_key] = Panic.Accounts.list_api_keys!(actor: admin)
    Panic.Accounts.destroy_api_key!(api_key, actor: admin)

    assert key |> api_conn() |> get("/api/networks") |> json(401)
  end

  test "a non-admin's key is forbidden" do
    key = api_key_for(Panic.Fixtures.user())

    assert %{"errors" => [%{"status" => "403"}]} =
             key |> api_conn() |> get("/api/networks") |> json(403)
  end

  test "keys lose access when their user stops being an admin" do
    {admin, key} = admin_with_api_key()

    admin
    |> Ash.Changeset.for_update(:set_admin, %{admin: false})
    |> Ash.update!(authorize?: false)

    assert key |> api_conn() |> get("/api/networks") |> json(403)
  end

  test "the OpenAPI spec and Swagger UI are public" do
    assert %{"paths" => paths} = build_conn() |> get("/api/open_api") |> json(200)
    assert Map.has_key?(paths, "/api/networks/{id}/start_run")

    assert build_conn() |> get("/api/swaggerui") |> html_response(200)
  end
end
