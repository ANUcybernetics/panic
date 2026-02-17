defmodule PanicWeb.NetworkLive.StaticDisplayTest do
  use PanicWeb.ConnCase, async: false
  use ExUnitProperties

  import PanicWeb.Helpers

  alias Panic.Fixtures

  describe "Static Display page" do
    setup do
      setup_web_test()

      user = Fixtures.user("password123")

      network =
        Panic.Engine.Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network", lockout_seconds: 1}, actor: user)
        |> Ash.create!()

      network = Panic.Engine.update_models!(network, ["dummy-t2i", "dummy-i2t"], actor: user)

      invocation =
        Panic.Engine.Invocation
        |> Ash.Changeset.for_create(:prepare_first, %{input: "test input", network: network}, actor: user)
        |> Ash.create!()

      invocation =
        invocation
        |> Ash.Changeset.for_update(:update_output, %{output: "test output"}, actor: user)
        |> Ash.update!()

      %{user: user, network: network, invocation: invocation}
    end

    test "displays static invocation page for anonymous users", %{
      conn: conn,
      invocation: invocation
    } do
      conn
      |> visit(~p"/display/static/#{invocation.id}")
      |> assert_has("#invocation-#{invocation.id}")
    end

    test "displays static invocation page for authenticated users", %{
      conn: conn,
      invocation: invocation
    } do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})

      conn
      |> visit(~p"/display/static/#{invocation.id}")
      |> assert_has("#invocation-#{invocation.id}")
    end

    test "shows invocation details", %{conn: conn, invocation: invocation} do
      conn
      |> visit(~p"/display/static/#{invocation.id}")
      |> assert_has("title", text: "network #{invocation.network_id}")
    end

    test "handles non-existent invocation gracefully", %{conn: conn} do
      non_existent_id = Ash.UUID.generate()

      assert_raise Ash.Error.Invalid, fn ->
        conn |> visit(~p"/display/static/#{non_existent_id}")
      end
    end

    test "displays invocation component", %{conn: conn, invocation: invocation} do
      conn
      |> visit(~p"/display/static/#{invocation.id}")
      |> assert_has("#invocation-#{invocation.id}")
    end
  end
end
