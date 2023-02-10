defmodule PanicWeb.PredictionLiveTest do
  use PanicWeb.ConnCase

  import Phoenix.LiveViewTest
  import Panic.{AccountsFixtures, NetworksFixtures, PredictionsFixtures}

  @create_attrs %{
    input: "some input",
    metadata: %{},
    model: "some model",
    output: "some output",
    run_index: 42
  }
  @update_attrs %{
    input: "some updated input",
    metadata: %{},
    model: "some updated model",
    output: "some updated output",
    run_index: 43
  }
  @invalid_attrs %{input: nil, metadata: nil, model: nil, output: nil, run_index: nil}

  def create_and_log_in_user(%{conn: conn} = context) do
    password = "123456789abcd"
    user = user_fixture(%{password: password})

    {:ok, lv, _html} = live(conn, ~p"/users/log_in")

    form =
      form(lv, "#login_form", user: %{email: user.email, password: password, remember_me: true})

    conn = submit_form(form, conn)

    context
    |> Map.put(:user, user)
    |> Map.put(:conn, conn)
  end

  def create_network(%{user: user} = context) do
    Map.put(context, :network, network_fixture(%{user_id: user.id}))
  end

  defp create_prediction(%{network: network} = context) do
    Map.put(context, :prediction, prediction_fixture(%{network_id: network.id}))
  end

  describe "Index" do
    setup [:create_and_log_in_user, :create_network, :create_prediction]

    test "lists all predictions", %{conn: conn, prediction: prediction} do
      {:ok, _index_live, html} = live(conn, ~p"/predictions")

      assert html =~ "Listing Predictions"
      assert html =~ prediction.input
    end

    test "saves new prediction", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/predictions")

      assert index_live |> element("a", "New Prediction") |> render_click() =~
               "New Prediction"

      assert_patch(index_live, ~p"/predictions/new")

      assert index_live
             |> form("#prediction-form", prediction: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#prediction-form", prediction: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/predictions")

      assert html =~ "Prediction created successfully"
      assert html =~ "some input"
    end

    test "updates prediction in listing", %{conn: conn, prediction: prediction} do
      {:ok, index_live, _html} = live(conn, ~p"/predictions")

      assert index_live |> element("#predictions-#{prediction.id} a", "Edit") |> render_click() =~
               "Edit Prediction"

      assert_patch(index_live, ~p"/predictions/#{prediction}/edit")

      assert index_live
             |> form("#prediction-form", prediction: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#prediction-form", prediction: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/predictions")

      assert html =~ "Prediction updated successfully"
      assert html =~ "some updated input"
    end

    test "deletes prediction in listing", %{conn: conn, prediction: prediction} do
      {:ok, index_live, _html} = live(conn, ~p"/predictions")

      assert index_live |> element("#predictions-#{prediction.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#prediction-#{prediction.id}")
    end
  end

  describe "Show" do
    setup [:create_and_log_in_user, :create_network, :create_prediction]

    test "displays prediction", %{conn: conn, prediction: prediction} do
      {:ok, _show_live, html} = live(conn, ~p"/predictions/#{prediction}")

      assert html =~ "Show Prediction"
      assert html =~ prediction.input
    end

    test "updates prediction within modal", %{conn: conn, prediction: prediction} do
      {:ok, show_live, _html} = live(conn, ~p"/predictions/#{prediction}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Prediction"

      assert_patch(show_live, ~p"/predictions/#{prediction}/show/edit")

      assert show_live
             |> form("#prediction-form", prediction: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#prediction-form", prediction: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/predictions/#{prediction}")

      assert html =~ "Prediction updated successfully"
      assert html =~ "some updated input"
    end
  end
end
