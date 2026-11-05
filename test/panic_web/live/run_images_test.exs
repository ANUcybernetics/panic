defmodule PanicWeb.RunImagesTest do
  @moduledoc """
  The page of a run's images at `/networks/:network_id/runs/:run_number`, which
  the terminal links to.
  """
  use PanicWeb.ConnCase, async: false
  use Repatch.ExUnit

  import Panic.EngineHelpers
  import Phoenix.LiveViewTest

  alias Panic.Engine
  alias Panic.Engine.Archiver
  alias Panic.Fixtures
  alias Panic.Test.ArchiverPatches
  alias PanicWeb.TerminalAuth

  @moduletag :capture_log

  setup do
    Panic.ExternalAPIPatches.setup()
    ArchiverPatches.apply_patches()
    user = Fixtures.user()

    network =
      "Run images"
      |> Engine.create_network!("t2i then i2t", actor: user)
      |> Engine.update_network!(%{lockout_seconds: 0, anon_terminal_minutes: 10}, actor: user)
      |> Engine.update_models!(["dummy-t2i", "dummy-i2t"], actor: user)

    %{user: user, network: network}
  end

  defp run_path(network, run_number), do: ~p"/networks/#{network}/runs/#{run_number}"

  # the run's images, newest first
  defp images(network, run_number) do
    Engine.list_invocations!(
      query: [
        filter: [
          network_id: network.id,
          run_number: run_number,
          model: "dummy-t2i",
          state: :completed
        ],
        sort: [sequence_number: :desc]
      ],
      authorize?: false
    )
  end

  defp slide(invocation), do: "#images-#{invocation.id}"

  defp slide_count(view), do: view |> render() |> Floki.parse_fragment!() |> Floki.find("li.slide") |> length()

  test "anyone can open a run's images, newest first, with only the newest loaded", %{
    conn: conn,
    user: user,
    network: network
  } do
    genesis = Engine.start_run!(network, "a cat", actor: user)
    # t2i, i2t, t2i: two images, and a caption between them
    for _ <- 1..3, do: run_next_invocation()

    assert [newest, older] = images(network, genesis.run_number)

    conn
    |> visit(run_path(network, genesis.run_number))
    |> assert_has("header", text: "a cat")
    |> assert_has("li.slide", count: 2)
    |> assert_has("#run-images-slides > li#{slide(newest)}:first-child")
    |> assert_has("#{slide(older)} + #run-images-empty")
    # the hook loads the rest as the viewer swipes back to them
    |> assert_has("#{slide(newest)} img[src='#{newest.output}'][data-src='#{newest.output}']")
    |> assert_has("#{slide(older)} img[data-src='#{older.output}']")
    |> refute_has("#{slide(older)} img[src]")
    # an image made from a text prompt is described by it
    |> assert_has("#{slide(older)} img[alt='#{older.input}']")
  end

  test "new images arrive as the run goes, and archiving gives them a placeholder", %{
    conn: conn,
    user: user,
    network: network
  } do
    genesis = Engine.start_run!(network, "a dog", actor: user)

    {:ok, view, _html} = live(conn, run_path(network, genesis.run_number))
    assert has_element?(view, "#run-images-empty", "No images yet")

    run_next_invocation()
    [first] = images(network, genesis.run_number)
    assert has_element?(view, "#{slide(first)} img[data-src='#{first.output}']")
    refute has_element?(view, "#{slide(first)}[style*='--placeholder']")

    # the caption the next model makes isn't an image
    run_next_invocation()
    assert slide_count(view) == 1

    run_next_invocation()
    [second, ^first] = images(network, genesis.run_number)
    assert has_element?(view, "#run-images-slides > li#{slide(second)}:first-child")

    Repatch.patch(Archiver, :upload_to_s3, [force: true], fn _file ->
      {:ok, "https://fly.storage.tigris.dev/panic-invocation-outputs/archived.webp"}
    end)

    drain_archiver()

    assert has_element?(
             view,
             "#{slide(first)} img[data-src='https://fly.storage.tigris.dev/panic-invocation-outputs/archived.webp']"
           )

    assert has_element?(
             view,
             "#{slide(first)}[style*='--placeholder: url(data:image/webp;base64,']"
           )

    assert slide_count(view) == 2
  end

  test "a run that isn't the network's is not found", %{conn: conn, user: user, network: network} do
    genesis = Engine.start_run!(network, "a bird", actor: user)
    run_next_invocation()
    run_next_invocation()
    other = Fixtures.network_with_dummy_models(user)

    assert conn |> get(run_path(other, genesis.run_number)) |> redirected_to() == "/404"

    # nor is an invocation that isn't a run's genesis
    caption = Engine.get_invocation_in_run!(genesis.run_number, 1, authorize?: false)
    assert conn |> get(run_path(network, caption.id)) |> redirected_to() == "/404"
    assert conn |> get(run_path(network, "nope")) |> redirected_to() == "/404"
  end

  test "a network's page links to its current run's images", %{conn: conn} do
    %{conn: conn, user: owner} = PanicWeb.Helpers.create_and_sign_in_user(%{conn: conn})
    network = Fixtures.network_with_dummy_models(owner)

    session = visit(conn, ~p"/networks/#{network}")
    refute_has(session, "#network-run-images")

    genesis = Engine.start_run!(network, "a frog", actor: owner)

    conn
    |> visit(~p"/networks/#{network}")
    |> click_link("#network-run-images", "Images")
    |> assert_path(run_path(network, genesis.run_number))
  end

  test "an anonymous terminal links to its run's images", %{conn: conn, network: network} do
    conn
    |> visit(~p"/networks/#{network}/terminal?token=#{TerminalAuth.token(network.id)}")
    |> refute_has("#terminal-run-images")
    |> fill_in("Start a new run", with: "a fish")
    |> submit()
    |> assert_has("#terminal-run-images[target='_blank']",
      text: "Swipe back through this run's images"
    )

    [genesis] =
      Engine.list_invocations!(
        query: [filter: [network_id: network.id, sequence_number: 0]],
        authorize?: false
      )

    conn
    |> visit(~p"/networks/#{network}/terminal?token=#{TerminalAuth.token(network.id)}")
    |> assert_has("#terminal-run-images[href='#{run_path(network, genesis.run_number)}']")
  end
end
