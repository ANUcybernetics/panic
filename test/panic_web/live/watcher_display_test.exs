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

  defp outputs(network) do
    Invocation
    |> Ash.Query.filter(network_id == ^network.id and state == :completed)
    |> Ash.Query.sort(sequence_number: :asc)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.sequence_number, &1.output})
  end

  defp shows?(view, slot, text), do: has_element?(view, "#slot-#{slot}", text)

  defp slot_count(view), do: length(Regex.scan(~r/id="slot-\d+"/, render(view)))

  defp shows_genesis?(view, slot), do: has_element?(view, "#slot-#{slot}", "P!")

  test "every watcher shows the run from the genesis onwards", %{
    user: user,
    network: network,
    views: views
  } do
    for {_name, view} <- views, do: assert(has_element?(view, "#display-info"))

    Engine.start_run!(network, "hello watchers", actor: user)

    assert shows_genesis?(views["wall"], 0)
    assert shows_genesis?(views["even"], 0)
    assert shows_genesis?(views["odd"], 1)
    assert shows_genesis?(views["board"], 1)

    run_next_invocation()
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

  test "a display opened before its first turn shows the genesis", %{
    conn: conn,
    user: user,
    network: network,
    installation: installation
  } do
    Engine.start_run!(network, "early arrival", actor: user)
    run_next_invocation()

    {:ok, odd, _html} = live(conn, ~p"/i/#{installation.id}/odd")
    assert slot_count(odd) == 1
    assert has_element?(odd, "#slot-1")
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

    Engine.start_run!(network, "second run", actor: user)

    assert shows_genesis?(views["wall"], 0)
    refute has_element?(views["wall"], "#slot-1")
    assert shows_genesis?(views["odd"], 1)
  end
end
