defmodule PanicWeb.Api.InstallationsTest do
  use PanicWeb.ConnCase, async: false

  import PanicWeb.ApiHelpers

  setup do
    {admin, key} = admin_with_api_key()
    network = Panic.Fixtures.network_with_dummy_models(admin)
    {:ok, admin: admin, key: key, network: network}
  end

  defp create_installation(key, network, watchers) do
    key
    |> api_conn()
    |> post(
      "/api/installations",
      body("installation", %{name: "Gallery", network_id: network.id, watchers: watchers})
    )
  end

  defp watcher_names(response), do: Enum.map(response["data"]["attributes"]["watchers"], & &1["name"])

  test "create, read, update and delete", %{key: key, network: network} do
    created =
      key
      |> create_installation(network, [%{type: "grid", name: "wall", rows: 2, columns: 3}])
      |> json(201)

    id = created["data"]["id"]

    assert %{"name" => "Gallery", "network_id" => network_id, "watchers" => [wall]} =
             created["data"]["attributes"]

    assert network_id == network.id
    assert %{"type" => "grid", "rows" => 2, "columns" => 3} = wall

    assert %{"data" => [%{"id" => ^id}]} =
             key |> api_conn() |> get("/api/installations") |> json(200)

    assert %{"data" => [%{"id" => ^id}]} =
             key |> api_conn() |> get("/api/networks/#{network.id}/installations") |> json(200)

    updated =
      key
      |> api_conn()
      |> patch("/api/installations/#{id}", body("installation", %{name: "Foyer"}))
      |> json(200)

    assert updated["data"]["attributes"]["name"] == "Foyer"

    key |> api_conn() |> delete("/api/installations/#{id}") |> json(200)
    assert key |> api_conn() |> get("/api/installations/#{id}") |> json(404)
  end

  test "add, update and remove watchers", %{key: key, network: network} do
    %{"data" => %{"id" => id}} = key |> create_installation(network, []) |> json(201)

    added =
      key
      |> api_conn()
      |> patch(
        "/api/installations/#{id}/add_watcher",
        body("installation", %{watcher: %{type: "single", name: "odd", stride: 2, offset: 1}})
      )
      |> json(200)

    assert watcher_names(added) == ["odd"]

    updated =
      key
      |> api_conn()
      |> patch(
        "/api/installations/#{id}/update_watcher",
        body("installation", %{
          watcher_name: "odd",
          updated_watcher: %{
            type: "vestaboard",
            name: "board",
            stride: 2,
            offset: 1,
            vestaboard_name: "panic_1"
          }
        })
      )
      |> json(200)

    assert [%{"name" => "board", "type" => "vestaboard", "vestaboard_name" => "panic_1"}] =
             updated["data"]["attributes"]["watchers"]

    removed =
      key
      |> api_conn()
      |> patch(
        "/api/installations/#{id}/remove_watcher",
        body("installation", %{watcher_name: "board"})
      )
      |> json(200)

    assert watcher_names(removed) == []
  end

  test "invalid watchers are rejected", %{key: key, network: network} do
    # a grid needs rows and columns
    assert %{"errors" => [_ | _]} =
             key |> create_installation(network, [%{type: "grid", name: "wall"}]) |> json(400)

    %{"data" => %{"id" => id}} =
      key
      |> create_installation(network, [%{type: "grid", name: "wall", rows: 1, columns: 1}])
      |> json(201)

    # watcher names are unique within an installation
    conn =
      key
      |> api_conn()
      |> patch(
        "/api/installations/#{id}/add_watcher",
        body("installation", %{watcher: %{type: "grid", name: "wall", rows: 2, columns: 2}})
      )

    assert %{"errors" => [_ | _]} = json(conn, 400)
  end

  test "other users' installations are invisible", %{key: key, network: network} do
    %{"data" => %{"id" => id}} = key |> create_installation(network, []) |> json(201)
    {_other_admin, other_key} = admin_with_api_key()

    assert %{"data" => []} = other_key |> api_conn() |> get("/api/installations") |> json(200)
    assert other_key |> api_conn() |> get("/api/installations/#{id}") |> json(404)
    assert other_key |> api_conn() |> delete("/api/installations/#{id}") |> json(404)
  end

  test "installations can't be put on other users' networks", %{key: key, network: network} do
    {other_admin, other_key} = admin_with_api_key()
    assert other_key |> create_installation(network, []) |> json(404)

    other_network = Panic.Fixtures.network_with_dummy_models(other_admin)
    %{"data" => %{"id" => id}} = key |> create_installation(network, []) |> json(201)

    conn =
      key
      |> api_conn()
      |> patch("/api/installations/#{id}", body("installation", %{network_id: other_network.id}))

    assert json(conn, 404)
  end
end
