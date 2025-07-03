defmodule PanicWeb.NetworkLive.StaticDisplayTest do
  use PanicWeb.ConnCase, async: false
  use ExUnitProperties

  import PanicWeb.Helpers
  import Phoenix.LiveViewTest

  alias Panic.Fixtures

  describe "Static Display page" do
    setup do
      setup_web_test()

      # Create test data directly
      user = Fixtures.user("password123")

      # Create network directly without generator
      network =
        Panic.Engine.Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network", lockout_seconds: 1}, actor: user)
        |> Ash.create!()

      # Add dummy models to the network
      network = Panic.Engine.update_models!(network, ["dummy-t2i", "dummy-i2t"], actor: user)

      # Create invocation after models are set
      invocation =
        Panic.Engine.Invocation
        |> Ash.Changeset.for_create(:prepare_first, %{input: "test input", network: network}, actor: user)
        |> Ash.create!()

      # Update the invocation to have output
      invocation =
        invocation
        |> Ash.Changeset.for_update(:update_output, %{output: "test output"}, actor: user)
        |> Ash.update!()

      %{user: user, network: network, invocation: invocation}
    end

    test "displays static invocation page for anonymous users", %{conn: conn, invocation: invocation} do
      {:ok, view, _html} = live(conn, ~p"/display/static/#{invocation.id}")

      # The static display shows the invocation
      assert has_element?(view, "#invocation-#{invocation.id}")
    end

    test "displays static invocation page for authenticated users", %{conn: conn, invocation: invocation} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})

      {:ok, view, _html} = live(conn, ~p"/display/static/#{invocation.id}")

      assert has_element?(view, "#invocation-#{invocation.id}")
    end

    test "shows invocation details", %{conn: conn, invocation: invocation} do
      {:ok, _view, html} = live(conn, ~p"/display/static/#{invocation.id}")

      # The page title includes the network ID in the HTML head
      assert html =~ "network #{invocation.network_id}"
    end

    test "handles non-existent invocation gracefully", %{conn: conn} do
      non_existent_id = Ash.UUID.generate()

      # With an invalid UUID, we get an Invalid error instead of NotFound
      assert_raise Ash.Error.Invalid, fn ->
        live(conn, ~p"/display/static/#{non_existent_id}")
      end
    end

    test "displays invocation component", %{conn: conn, invocation: invocation} do
      {:ok, view, _html} = live(conn, ~p"/display/static/#{invocation.id}")

      assert has_element?(view, "#invocation-#{invocation.id}")
    end
  end
end
