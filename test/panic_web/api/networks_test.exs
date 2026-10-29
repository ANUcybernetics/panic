defmodule PanicWeb.Api.NetworksTest do
  use PanicWeb.ConnCase, async: false

  import Panic.EngineHelpers
  import PanicWeb.ApiHelpers

  @moduletag :capture_log

  setup do
    {admin, key} = admin_with_api_key()
    {:ok, admin: admin, key: key}
  end

  defp create_network(key, attrs \\ %{}) do
    attrs = Map.merge(%{name: "API network", description: "made over the API"}, attrs)

    key
    |> api_conn()
    |> post("/api/networks", body("network", attrs))
    |> json(201)
    |> Map.fetch!("data")
  end

  defp runnable_network(key) do
    %{"id" => id} = create_network(key, %{lockout_seconds: 0})

    key
    |> api_conn()
    |> patch("/api/networks/#{id}/models", body("network", %{models: ["dummy-t2t", "dummy-t2t"]}))
    |> json(200)

    id
  end

  defp start_run(key, id, input) do
    key |> api_conn() |> patch("/api/networks/#{id}/start_run", body("network", %{input: input}))
  end

  defp network(key, id), do: key |> api_conn() |> get("/api/networks/#{id}") |> json(200) |> Map.fetch!("data")

  describe "networks" do
    test "the anonymous terminal is off by default, and can be turned on and off", %{key: key} do
      %{"id" => id, "attributes" => attributes} = create_network(key)
      assert attributes["anon_terminal_minutes"] == nil

      patch_minutes = fn minutes ->
        key
        |> api_conn()
        |> patch("/api/networks/#{id}", body("network", %{anon_terminal_minutes: minutes}))
      end

      assert 15
             |> patch_minutes.()
             |> json(200)
             |> get_in(["data", "attributes", "anon_terminal_minutes"]) == 15

      assert nil
             |> patch_minutes.()
             |> json(200)
             |> get_in(["data", "attributes", "anon_terminal_minutes"]) == nil

      assert %{"errors" => [_ | _]} = 0 |> patch_minutes.() |> json(400)
    end

    test "create, read, update and delete", %{key: key} do
      created = create_network(key, %{lockout_seconds: 5})

      assert %{"name" => "API network", "lockout_seconds" => 5, "models" => []} =
               created["attributes"]

      assert %{"data" => [%{"id" => id}]} = key |> api_conn() |> get("/api/networks") |> json(200)
      assert id == created["id"]
      assert network(key, id)["attributes"]["description"] == "made over the API"

      updated =
        key
        |> api_conn()
        |> patch("/api/networks/#{id}", body("network", %{name: "Renamed", lockout_seconds: 60}))
        |> json(200)

      assert %{"name" => "Renamed", "lockout_seconds" => 60} = updated["data"]["attributes"]

      key |> api_conn() |> delete("/api/networks/#{id}") |> json(200)
      assert key |> api_conn() |> get("/api/networks/#{id}") |> json(404)
    end

    test "creating without a name is rejected", %{key: key} do
      conn =
        key |> api_conn() |> post("/api/networks", body("network", %{description: "nameless"}))

      assert %{"errors" => [_ | _]} = json(conn, 400)
    end

    test "models are validated like they are in the UI", %{key: key} do
      %{"id" => id} = create_network(key)

      conn =
        key
        |> api_conn()
        |> patch(
          "/api/networks/#{id}/models",
          body("network", %{models: ["dummy-t2i", "dummy-t2i"]})
        )

      assert %{"errors" => [_ | _]} = json(conn, 400)
      assert network(key, id)["attributes"]["models"] == []

      conn =
        key
        |> api_conn()
        |> patch(
          "/api/networks/#{id}/models",
          body("network", %{models: ["dummy-t2i", "dummy-i2t"]})
        )

      assert json(conn, 200)["data"]["attributes"]["models"] == ["dummy-t2i", "dummy-i2t"]
    end

    test "other users' networks are invisible", %{key: key} do
      %{"id" => id} = create_network(key)
      {_other_admin, other_key} = admin_with_api_key()

      assert %{"data" => []} = other_key |> api_conn() |> get("/api/networks") |> json(200)
      assert other_key |> api_conn() |> get("/api/networks/#{id}") |> json(404)

      assert other_key
             |> api_conn()
             |> patch("/api/networks/#{id}", body("network", %{name: "mine"}))
             |> json(404)

      assert other_key |> start_run(id, "hijack") |> json(404)
      assert network(key, id)["attributes"]["current_run_number"] == nil
    end
  end

  describe "runs" do
    test "start a run, follow its invocations, then stop it", %{key: key} do
      id = runnable_network(key)

      started = key |> start_run(id, "hello api") |> json(200)
      run_number = started["data"]["attributes"]["current_run_number"]
      assert is_integer(run_number)
      assert started["data"]["attributes"]["run_started_at"]

      run_next_invocation()
      run_next_invocation()

      %{"data" => invocations} =
        key
        |> api_conn()
        |> get("/api/invocations?filter[network_id]=#{id}&filter[run_number]=#{run_number}&sort=sequence_number")
        |> json(200)

      assert [
               %{
                 "attributes" =>
                   %{"sequence_number" => 0, "input" => "hello api", "state" => "completed"} =
                     first
               },
               %{"attributes" => %{"sequence_number" => 1, "state" => "completed"} = second},
               %{"attributes" => %{"sequence_number" => 2, "state" => "ready"}}
             ] = invocations

      assert second["input"] == first["output"]

      assert %{"data" => related} =
               key |> api_conn() |> get("/api/networks/#{id}/invocations") |> json(200)

      assert length(related) == 3

      [%{"id" => invocation_id} | _] = invocations

      assert %{"data" => %{"attributes" => %{"output" => output}}} =
               key |> api_conn() |> get("/api/invocations/#{invocation_id}") |> json(200)

      assert output == first["output"]

      stopped =
        key
        |> api_conn()
        |> patch("/api/networks/#{id}/stop_run", Jason.encode!(%{data: %{}}))
        |> json(200)

      assert stopped["data"]["attributes"]["current_run_number"] == nil

      # the pending invocation never runs
      run_next_invocation()

      assert %{"data" => %{"attributes" => %{"state" => "ready"}}} =
               key
               |> api_conn()
               |> get("/api/invocations/#{List.last(invocations)["id"]}")
               |> json(200)
    end

    test "invocations can be paginated", %{key: key} do
      id = runnable_network(key)
      key |> start_run(id, "pages") |> json(200)
      run_next_invocation()

      assert %{"data" => [%{"attributes" => %{"sequence_number" => 1}}]} =
               key
               |> api_conn()
               |> get("/api/invocations?filter[network_id]=#{id}&sort=-sequence_number&page[limit]=1")
               |> json(200)
    end

    test "a run can't be replaced during its lockout", %{key: key} do
      id = runnable_network(key)

      key
      |> api_conn()
      |> patch("/api/networks/#{id}", body("network", %{lockout_seconds: 600}))
      |> json(200)

      first = key |> start_run(id, "first") |> json(200)
      assert %{"errors" => [_ | _]} = key |> start_run(id, "second") |> json(400)

      assert network(key, id)["attributes"]["current_run_number"] ==
               first["data"]["attributes"]["current_run_number"]
    end

    test "a network without models can't start a run", %{key: key} do
      %{"id" => id} = create_network(key)
      assert %{"errors" => [_ | _]} = key |> start_run(id, "nothing to run") |> json(400)
    end
  end

  test "lists the available models", %{key: key} do
    models = key |> api_conn() |> get("/api/models") |> json(200)

    assert %{"input_type" => "text", "output_type" => "text", "platform" => "dummy"} =
             Enum.find(models, &(&1["id"] == "dummy-t2t"))
  end
end
