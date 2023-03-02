defmodule PanicWeb.PredictionLiveTest do
  use PanicWeb.ConnCase

  import Phoenix.LiveViewTest
  import Panic.{AccountsFixtures, NetworksFixtures, PredictionsFixtures}

  import Mock

  @create_attrs %{input: "why did the chicken cross the road?"}

  def create_and_log_in_user(%{conn: conn} = context) do
    password = "123456789abcd"
    user = user_fixture(%{password: password})
    insert_api_tokens_from_env(user.id)

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
    Map.put(
      context,
      :prediction,
      prediction_fixture(%{network_id: network.id, model: List.first(network.models)})
    )
  end

  describe "Index" do
    setup [:create_and_log_in_user, :create_network, :create_prediction]

    test "lists all predictions", %{conn: conn, network: network, prediction: prediction} do
      {:ok, _index_live, html} = live(conn, ~p"/networks/#{network}/predictions")

      assert html =~ "Listing Predictions"
      assert html =~ prediction.output
    end

    test_with_mock "creates a new prediction using the terminal",
                   %{conn: conn, network: network},
                   Panic.Platforms,
                   [:passthrough],
                   api_call: fn model_id, _input, _user ->
                     Process.sleep(1000)
                     {:ok, "result of API call to #{model_id}"}
                   end do
      {:ok, index_live, _html} = live(conn, ~p"/networks/#{network}/predictions/new")

      assert index_live
             |> form("#terminal-input", prediction: @create_attrs)
             |> render_submit()

      # TODO maybe check here that the predictions are actually created? not
      # 100% sure how, though
    end
  end

  describe "Show" do
    setup [:create_and_log_in_user, :create_network, :create_prediction]

    test "displays prediction", %{conn: conn, network: network, prediction: prediction} do
      {:ok, _show_live, html} = live(conn, ~p"/networks/#{network}/predictions/#{prediction}")

      assert html =~ "Show Prediction"
    end
  end
end
