defmodule PanicWeb.NetworkLive.ModelSelectComponentTest do
  @moduledoc """
  Tests for the ModelSelectComponent UI functionality.
  """
  use PanicWeb.ConnCase, async: false

  alias PanicWeb.Helpers

  setup do
    Helpers.stop_all_network_runners()
    :ok
  end

  describe "component rendering" do
    setup {Helpers, :create_and_sign_in_user}

    test "renders LiveSelect component with correct attributes", %{conn: conn, user: user} do
      network = create_test_network(user)

      conn
      |> visit(~p"/networks/#{network}")
      |> assert_has("#model-select-input")
      |> assert_has("input[placeholder='Add model...']")
      |> assert_has("span", text: "Valid network")
      |> assert_has("td", text: "Dummy Text-to-Text")
    end

    test "shows models in table format", %{conn: conn, user: user} do
      network = create_test_network(user, ["dummy-t2i", "dummy-i2t"])

      conn
      |> visit(~p"/networks/#{network}")
      |> assert_has("table")
      |> assert_has("th", text: "Model Name")
      |> assert_has("th", text: "Type")
      |> assert_has("td", text: "Dummy Text-to-Image")
      |> assert_has("td", text: "Dummy Image-to-Text")
    end

    test "displays I/O type indicators with colors", %{conn: conn, user: user} do
      network = create_test_network(user, ["dummy-t2i", "dummy-i2t"])

      conn
      |> visit(~p"/networks/#{network}")
      |> assert_has("span", text: "text")
      |> assert_has("span", text: "image")
      |> assert_has("span.text-blue-400")
      |> assert_has("span.text-violet-400")
    end
  end

  describe "model removal" do
    setup {Helpers, :create_and_sign_in_user}

    test "shows remove button on model items", %{conn: conn, user: user} do
      network = create_test_network(user, ["dummy-t2t"])

      conn
      |> visit(~p"/networks/#{network}")
      |> assert_has("button[phx-click='remove_model']")
    end

    test "removes model when remove button clicked", %{conn: conn, user: user} do
      network = create_test_network(user, ["dummy-t2t", "dummy-t2t", "dummy-t2t"])

      conn
      |> visit(~p"/networks/#{network}")
      |> click_button("button[phx-click='remove_model'][phx-value-index='0']", "")
      |> click_button("Save Network")

      updated_network = Ash.get!(Panic.Engine.Network, network.id, actor: user)
      assert updated_network.models == ["dummy-t2t", "dummy-t2t"]
    end
  end

  describe "LiveSelect search functionality" do
    setup {Helpers, :create_and_sign_in_user}

    test "renders LiveSelect dropdown element", %{conn: conn, user: user} do
      network = create_test_network(user)

      conn
      |> visit(~p"/networks/#{network}")
      |> assert_has("#model-select-input")
    end
  end

  defp create_test_network(user, models \\ ["dummy-t2t"]) do
    network =
      Panic.Engine.create_network!(
        "Test Network",
        "Test network for component tests",
        actor: user
      )

    if models != [] && valid_model_chain?(models) do
      Panic.Engine.update_models!(network, models, actor: user)
    else
      network
    end
  end

  defp valid_model_chain?([]), do: false

  defp valid_model_chain?(model_ids) do
    models = Enum.map(model_ids, &Panic.Model.by_id!/1)

    sequential_valid? =
      [%{output_type: :text} | models]
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn [m1, m2] -> m1.output_type == m2.input_type end)

    first = List.first(models)
    last = List.last(models)
    cycle_valid? = last.output_type == first.input_type

    sequential_valid? && cycle_valid?
  end
end
