defmodule PanicWeb.WatcherDisplayTest do
  @moduledoc """
  Installation watcher displays (`/i/:id/:watcher_name`) following a run as the
  engine drives it, viewed anonymously the way the kiosk displays are.
  """
  use PanicWeb.ConnCase, async: false
  use Repatch.ExUnit

  import Panic.EngineHelpers
  import Phoenix.LiveViewTest

  alias Panic.Engine
  alias Panic.Engine.Archiver
  alias Panic.Engine.Invocation
  alias Panic.Watcher.Installation

  require Ash.Query

  @moduletag :capture_log

  setup %{conn: conn} do
    user = Panic.Fixtures.user()

    network =
      "Watcher display network"
      |> Engine.create_network!("for watcher display tests", actor: user)
      |> Ash.Changeset.for_update(:update, %{lockout_seconds: 0}, actor: user)
      |> Ash.update!()
      |> Engine.update_models!(["dummy-t2t", "dummy-t2t"], actor: user)

    installation =
      Installation
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: "Gallery",
          network_id: network.id,
          vestaboard_hold_seconds: 0,
          watchers: [
            %{type: :grid, name: "wall", rows: 2, columns: 2},
            %{type: :single, name: "even", stride: 2, offset: 0},
            %{type: :single, name: "odd", stride: 2, offset: 1},
            %{type: :vestaboard, name: "board", stride: 2, offset: 1, vestaboard_name: :panic_1}
          ]
        },
        actor: user
      )
      |> Ash.create!()

    views =
      Map.new(~w(wall even odd board), fn name ->
        {:ok, view, _html} = live(conn, ~p"/i/#{installation.id}/#{name}")
        {name, view}
      end)

    {:ok, conn: conn, user: user, network: network, installation: installation, views: views}
  end

  defp outputs(network), do: network |> completed() |> Map.new(fn {seq, inv} -> {seq, inv.output} end)

  defp completed(network) do
    Invocation
    |> Ash.Query.filter(network_id == ^network.id and state == :completed)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.sequence_number, &1})
  end

  defp shows?(view, slot, text), do: has_element?(view, "#slot-#{slot}", text)

  defp slot_count(view), do: length(Regex.scan(~r/id="slot-\d+"/, render(view)))

  defp shows_genesis?(view, slot), do: has_element?(view, "#slot-#{slot}", "P!")

  test "the grid and the first screen show the genesis, and the other screens stay blank until their turn",
       %{
         user: user,
         network: network,
         views: views
       } do
    for {_name, view} <- views, do: assert(has_element?(view, "#display-info"))

    Engine.start_run!(network, "hello watchers", actor: user)

    assert shows_genesis?(views["wall"], 0)
    assert shows_genesis?(views["even"], 0)
    for name <- ~w(odd board), do: assert(slot_count(views[name]) == 0)

    run_next_invocation()
    for name <- ~w(odd board), do: assert(slot_count(views[name]) == 0)

    run_next_invocation()
    run_next_invocation()
    outputs = outputs(network)
    assert map_size(outputs) == 3

    # the grid shows every invocation in its slot
    for seq <- 0..2, do: assert(shows?(views["wall"], seq, outputs[seq]))

    # single watchers show only the latest invocation in their stride
    assert shows?(views["even"], 0, outputs[2])
    for name <- ~w(even odd board), do: assert(slot_count(views[name]) == 1)
    assert shows?(views["odd"], 1, outputs[1])
    assert shows?(views["board"], 1, outputs[1])
  end

  test "the first screen's grid keeps its last cell for the run, and rotates through the rest", %{
    user: user,
    network: network,
    views: views
  } do
    Engine.start_run!(network, "round the wall", actor: user)
    for _ <- 1..4, do: run_next_invocation()
    outputs = outputs(network)

    # a 2x2 grid with its last cell kept back rotates through three slots
    assert has_element?(views["wall"], "#reserved-cell #run-hud")
    assert shows?(views["wall"], 0, outputs[3])
    assert slot_count(views["wall"]) == 3
  end

  test "a single screen fits its text to the screen, while a grid's cards share one size", %{
    user: user,
    network: network,
    views: views
  } do
    Engine.start_run!(network, "fit me", actor: user)
    run_next_invocation()

    assert has_element?(
             views["even"],
             ~s(#slot-0-text-fit[phx-hook="PanicWeb.PanicComponents.FitText"])
           )

    assert has_element?(views["even"], ~s(#slot-0-text-fit > div[style*="font-size"]))
    refute has_element?(views["wall"], "#slot-0-text-fit[phx-hook]")
    refute has_element?(views["wall"], ~s(#slot-0-text-fit > div[style*="font-size"]))
  end

  test "a single screen captions what it shows with the model that made it and from what", %{
    user: user,
    network: network,
    views: views
  } do
    Engine.start_run!(network, "caption me", actor: user)
    assert has_element?(views["even"], "#slot-0-caption", "now running")
    refute has_element?(views["even"], "#slot-0-caption-time")

    run_next_invocation()
    assert has_element?(views["even"], "#slot-0-caption", "text by")
    made_at = DateTime.to_iso8601(completed(network)[0].updated_at)
    assert has_element?(views["even"], ~s(#slot-0-caption-time[datetime="#{made_at}"]))
    assert has_element?(views["even"], "#slot-0-caption-model", "Dummy Text-to-Text")
    assert has_element?(views["even"], "#slot-0-caption", "from the initial prompt")
    assert has_element?(views["even"], "#slot-0-caption-input", "caption me")

    run_next_invocation()
    assert has_element?(views["odd"], "#slot-1-caption-source", "Dummy Text-to-Text")
    assert has_element?(views["odd"], "#slot-1-caption-input", outputs(network)[0])

    refute has_element?(views["wall"], "#slot-0-caption")
  end

  test "a display opened mid-run picks up from the next invocation", %{
    conn: conn,
    user: user,
    network: network,
    installation: installation
  } do
    Engine.start_run!(network, "late arrival", actor: user)
    run_next_invocation()

    {:ok, late, _html} = live(conn, ~p"/i/#{installation.id}/wall")
    assert render(late) =~ "late arrival"

    run_next_invocation()
    assert shows?(late, 1, outputs(network)[1])
  end

  test "a display opened mid-run shows what it would have been showing", %{
    conn: conn,
    user: user,
    network: network,
    installation: installation
  } do
    Engine.start_run!(network, "reloaded kiosk", actor: user)
    run_next_invocation()
    run_next_invocation()
    run_next_invocation()
    outputs = outputs(network)

    {:ok, even, _html} = live(conn, ~p"/i/#{installation.id}/even")
    {:ok, odd, _html} = live(conn, ~p"/i/#{installation.id}/odd")
    {:ok, wall, _html} = live(conn, ~p"/i/#{installation.id}/wall")

    assert shows?(even, 0, outputs[2])
    assert shows?(odd, 1, outputs[1])
    for name <- [even, odd], do: assert(slot_count(name) == 1)
    for seq <- 0..2, do: assert(shows?(wall, seq, outputs[seq]))
  end

  test "a display opened before its first turn stays blank, unless it's the first", %{
    conn: conn,
    user: user,
    network: network,
    installation: installation
  } do
    Engine.start_run!(network, "early arrival", actor: user)

    {:ok, even, _html} = live(conn, ~p"/i/#{installation.id}/even")
    assert shows_genesis?(even, 0)

    run_next_invocation()

    {:ok, odd, _html} = live(conn, ~p"/i/#{installation.id}/odd")
    assert slot_count(odd) == 0
  end

  describe "an installation's grid screens" do
    # n 2x2 screens: the first keeps a cell for the run summary, so together
    # they're a grid of 3 + 4(n - 1) cells
    defp grid_screens(user, network, n) do
      Installation
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: "#{n} screens",
          network_id: network.id,
          watchers: for(i <- 1..n, do: %{type: :grid, name: "screen-#{i}", rows: 2, columns: 2})
        },
        actor: user
      )
      |> Ash.create!()
    end

    defp open_screens(conn, installation) do
      for %{name: name} <- installation.watchers do
        {:ok, view, _html} = live(conn, ~p"/i/#{installation.id}/#{name}")
        view
      end
    end

    defp total_cells(screens), do: 3 + 4 * (length(screens) - 1)

    # after a run one past a full grid, so the last output has wrapped round
    # onto the first cell, each screen shows its own run of cells
    defp assert_one_grid(screens, outputs) do
      total = total_cells(screens)

      screens
      |> Enum.with_index()
      |> Enum.reduce(0, fn {view, index}, first ->
        cells = if index == 0, do: 3, else: 4
        assert slot_count(view) == cells

        for slot <- 0..(cells - 1) do
          position = first + slot
          assert shows?(view, slot, outputs[if(position == 0, do: total, else: position)])
        end

        first + cells
      end)
    end

    for n <- [2, 3] do
      test "#{n} screens are one grid: each continues where the last ends, and they wrap round together",
           %{conn: conn, user: user, network: network} do
        [first | rest] = screens = open_screens(conn, grid_screens(user, network, unquote(n)))

        Engine.start_run!(network, "one grid prompt", actor: user)
        assert shows_genesis?(first, 0)
        for view <- rest, do: assert(slot_count(view) == 0)
        for view <- screens, do: assert(render(view) =~ "one grid prompt")

        for _ <- 0..total_cells(screens), do: run_next_invocation()
        assert_one_grid(screens, outputs(network))
      end
    end

    test "screens opened mid-run show their part of the grid", %{
      conn: conn,
      user: user,
      network: network
    } do
      installation = grid_screens(user, network, 3)
      Engine.start_run!(network, "late screens", actor: user)
      for _ <- 0..total_cells(installation.watchers), do: run_next_invocation()

      installation
      |> then(&open_screens(conn, &1))
      |> assert_one_grid(outputs(network))
    end
  end

  test "a screen shows an output made from an archived image, and isn't disturbed by the archiving",
       %{conn: conn, user: user} do
    # archived copies live on Tigris, as in production
    Repatch.patch(Archiver, :download_file, fn _url ->
      {:ok, "/tmp/archived.webp"}
    end)

    Repatch.patch(Archiver, :convert_file, fn file, _rootname -> {:ok, file} end)

    Repatch.patch(Archiver, :upload_to_s3, fn path ->
      {:ok, "https://fly.storage.tigris.dev/panic-invocation-outputs/#{Path.basename(path)}"}
    end)

    network =
      "Archived images"
      |> Engine.create_network!("t2i then i2t", actor: user)
      |> Ash.Changeset.for_update(:update, %{lockout_seconds: 0}, actor: user)
      |> Ash.update!()
      |> Engine.update_models!(["dummy-t2i", "dummy-i2t"], actor: user)

    installation =
      Installation
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: "Archive",
          network_id: network.id,
          watchers: [%{type: :grid, name: "wall", rows: 2, columns: 2}]
        },
        actor: user
      )
      |> Ash.create!()

    {:ok, wall, _html} = live(conn, ~p"/i/#{installation.id}/wall")

    Engine.start_run!(network, "a cat", actor: user)
    run_next_invocation()
    image = outputs(network)[0]
    assert has_element?(wall, "#slot-0 img[src='#{image}']")

    # archiving rewrites the image's URL, and the next input, to the archived copy
    drain_archiver()
    assert has_element?(wall, "#slot-0 img[src='#{image}']")

    run_next_invocation()
    assert shows?(wall, 1, outputs(network)[1])
  end

  test "a display running out-of-date assets reloads itself", %{
    conn: conn,
    installation: installation
  } do
    # the test endpoint has no digest manifest to compare assets against
    Repatch.patch(Phoenix.LiveView, :static_changed?, [mode: :global], fn _socket -> true end)
    path = ~p"/i/#{installation.id}/even"

    assert {:error, {:redirect, %{to: ^path}}} = live(conn, path)
  end

  test "stopping a run freezes every display", %{user: user, network: network, views: views} do
    Engine.start_run!(network, "stop me", actor: user)
    run_next_invocation()
    before = Map.new(views, fn {name, view} -> {name, render(view)} end)

    Engine.stop_run!(network, actor: user)
    run_next_invocation()

    assert network |> outputs() |> Map.keys() == [0]
    for {name, view} <- views, do: assert(render(view) == before[name])
  end

  test "a new run replaces the old one on every display", %{
    user: user,
    network: network,
    views: views
  } do
    Engine.start_run!(network, "first run", actor: user)
    run_next_invocation()
    run_next_invocation()

    assert has_element?(views["odd"], "#slot-1")

    Engine.start_run!(network, "second run", actor: user)

    assert shows_genesis?(views["wall"], 0)
    refute has_element?(views["wall"], "#slot-1")
    assert shows_genesis?(views["even"], 0)
    assert slot_count(views["odd"]) == 0
  end
end
