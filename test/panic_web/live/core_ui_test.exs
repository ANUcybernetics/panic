defmodule PanicWeb.CoreUITest do
  @moduledoc """
  Behaviour of the shared UI components: modals, form errors, image alt text
  and page titles.
  """
  use PanicWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Panic.Engine.Invocation
  alias PanicWeb.PanicComponents

  describe "modal" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "renders a native dialog that the Modal hook opens", %{conn: conn} do
      conn
      |> visit(~p"/networks/new")
      |> assert_has(~s(dialog#new-network-modal[phx-hook="PanicWeb.CoreComponents.Modal"][data-show="true"]))
      |> assert_has(~s(#new-network-modal form[method="dialog"] button[aria-label="close"]))
      |> assert_has(~s(#new-network-modal form[method="dialog"].modal-backdrop))
    end

    test "carries on_cancel for the hook to run when the user closes it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/networks/new")

      cancel = view |> element("#new-network-modal") |> render() |> Floki.parse_fragment!()
      [encoded] = Floki.attribute(cancel, "dialog", "data-cancel")

      assert [["patch", %{"href" => href}]] = Jason.decode!(encoded)
      assert href == ~p"/networks"
    end

    test "toggles data-show when it stays in the DOM", %{conn: conn, user: user} do
      network = Panic.Fixtures.network_with_dummy_models(user)

      conn
      |> visit(~p"/networks/#{network}/info")
      |> assert_has(~s(dialog#qr-modal[data-show="false"]))
      |> visit(~p"/networks/#{network}/info/qr")
      |> assert_has(~s(dialog#qr-modal[data-show="true"]))
    end
  end

  describe "form errors" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "stay hidden on fields the user hasn't used", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/networks/new")

      # LiveView marks untouched fields with _unused_ params
      html =
        view
        |> element("#network-form")
        |> render_change(%{
          "network" => %{"name" => "", "_unused_name" => "", "description" => "x"}
        })

      refute html =~ "is required"
      refute has_element?(view, ~s(#network_name[aria-invalid]))
    end

    test "show on used fields and are linked to the input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/networks/new")

      view
      |> element("#network-form")
      |> render_change(%{"network" => %{"name" => "", "description" => "x"}})

      assert has_element?(
               view,
               ~s(#network_name[aria-invalid="true"][aria-describedby="network_name-error"])
             )

      assert has_element?(view, "#network_name-error", "is required")
    end
  end

  describe "invocation image" do
    test "uses a text prompt as its alt text" do
      html =
        render_component(&PanicComponents.invocation/1,
          id: "inv",
          invocation: %Invocation{
            state: :completed,
            input: "a red bicycle",
            output: "https://example.com/a.png"
          },
          model: Panic.Model.by_id!("dummy-t2i")
        )

      assert html =~ ~s(alt="a red bicycle")
    end

    test "has empty alt text when the prompt was an image" do
      html =
        render_component(&PanicComponents.invocation/1,
          id: "inv",
          invocation: %Invocation{
            state: :completed,
            input: "https://example.com/in.png",
            output: "https://example.com/out.png"
          },
          model: Panic.Model.by_id!("dummy-i2i")
        )

      assert html =~ ~s(alt="")
    end
  end

  test "page titles carry the app name", %{conn: conn} do
    conn
    |> visit(~p"/about")
    |> assert_has("title", text: "· PANIC!")
  end
end
