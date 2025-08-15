defmodule PanicWeb.NetworkLive.ModelSelectComponentTest do
  @moduledoc """
  Tests for the ModelSelectComponent UI functionality.

  These tests focus on the LiveSelect integration and UI behavior,
  not the model validation logic (which is tested in model_io_connections_test.exs).
  """
  use PanicWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PanicWeb.Helpers

  setup do
    Helpers.stop_all_network_runners()
    :ok
  end

  describe "component rendering" do
    setup {Helpers, :create_and_sign_in_user}

    test "renders LiveSelect component with correct attributes", %{conn: conn, user: user} do
      # Create a network with dummy models for testing
      network = create_test_network(user)

      {:ok, _view, html} = live(conn, ~p"/networks/#{network}")

      # Check that LiveSelect is rendered
      assert html =~ "model-select-input"
      assert html =~ "Add model..."

      # Check that validity indicator is present
      assert html =~ "Valid network"
      # Check that model names are shown in table
      assert html =~ "Dummy Text-to-Text"
    end

    test "shows models in table format", %{conn: conn, user: user} do
      # Create a valid cycle: text -> image -> text
      network = create_test_network(user, ["dummy-t2i", "dummy-i2t"])

      {:ok, _view, html} = live(conn, ~p"/networks/#{network}")

      # Should show the models in a table
      assert html =~ "<table"
      assert html =~ "Model Name"
      assert html =~ "Type"
      assert html =~ "Dummy Text-to-Image"
      assert html =~ "Dummy Image-to-Text"
    end

    test "displays I/O type indicators with colors", %{conn: conn, user: user} do
      # Create a valid cycle with both text and image types
      network = create_test_network(user, ["dummy-t2i", "dummy-i2t"])

      {:ok, _view, html} = live(conn, ~p"/networks/#{network}")

      # Should show I/O type badges with type labels
      assert html =~ "text → image"
      assert html =~ "image → text"
      # Check for colored badge styling
      assert html =~ "text-blue-400"
      assert html =~ "text-violet-400"
    end
  end

  describe "model removal" do
    setup {Helpers, :create_and_sign_in_user}

    test "shows remove button on model items", %{conn: conn, user: user} do
      network = create_test_network(user, ["dummy-t2t"])

      {:ok, _view, html} = live(conn, ~p"/networks/#{network}")

      # Remove button should be in the HTML (using trash icon now)
      assert html =~ "hero-trash"
      assert html =~ "phx-click=\"remove_model\""
    end

    test "removes model when remove button clicked", %{conn: conn, user: user} do
      network = create_test_network(user, ["dummy-t2t", "dummy-t2t", "dummy-t2t"])

      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      # Remove the first model (index 0)
      view
      |> element(~s(button[phx-click="remove_model"][phx-value-index="0"]))
      |> render_click()

      # Now save the changes
      view
      |> element("button[phx-click=\"save_models\"]")
      |> render_click()

      # Check that the model was removed and saved
      updated_network = Ash.get!(Panic.Engine.Network, network.id, actor: user)
      assert updated_network.models == ["dummy-t2t", "dummy-t2t"]
    end
  end

  describe "LiveSelect search functionality" do
    setup {Helpers, :create_and_sign_in_user}

    test "renders LiveSelect dropdown element", %{conn: conn, user: user} do
      network = create_test_network(user)

      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      # Check that the LiveSelect component is rendered
      assert has_element?(view, "#model-select-input")
    end

    # These tests are simplified to avoid complex LiveSelect interactions
    # The core model management functionality is tested in the integration tests
  end

  # Helper to create a test network with dummy models
  defp create_test_network(user, models \\ ["dummy-t2t"]) do
    network =
      Panic.Engine.create_network!(
        "Test Network",
        "Test network for component tests",
        actor: user
      )

    # Only update models if a valid configuration is provided
    # The network starts with empty models by default
    if models != [] && valid_model_chain?(models) do
      Panic.Engine.update_models!(network, models, actor: user)
    else
      network
    end
  end

  # Check if a model chain forms a valid cycle
  defp valid_model_chain?([]), do: false

  defp valid_model_chain?(model_ids) do
    models = Enum.map(model_ids, &Panic.Model.by_id!/1)

    # Check sequential connections
    sequential_valid? =
      [%{output_type: :text} | models]
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn [m1, m2] -> m1.output_type == m2.input_type end)

    # Check cycle
    first = List.first(models)
    last = List.last(models)
    cycle_valid? = last.output_type == first.input_type

    sequential_valid? && cycle_valid?
  end
end
