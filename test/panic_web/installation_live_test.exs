defmodule PanicWeb.InstallationLiveTest do
  @moduledoc """
  Editing an installation's settings from its page.
  """
  use PanicWeb.ConnCase, async: false

  alias Panic.Engine
  alias Panic.Watcher.Installation

  setup {PanicWeb.Helpers, :create_and_sign_in_user}

  test "the Vestaboard hold can be tuned on the installation page", %{conn: conn, user: user} do
    network = Engine.create_network!("Hold network", "for installation tests", actor: user)

    installation =
      Installation
      |> Ash.Changeset.for_create(:create, %{name: "Birch", network_id: network.id}, actor: user)
      |> Ash.create!()

    assert installation.vestaboard_hold_seconds == 10

    conn
    |> visit("/installations/#{installation.id}")
    |> assert_has("p", text: "Vestaboard hold: 10s")
    |> click_link("Edit installation")
    |> fill_in("Vestaboard hold (seconds)", with: "7")
    |> submit()
    |> assert_has("p", text: "Vestaboard hold: 7s")

    assert Ash.reload!(installation, authorize?: false).vestaboard_hold_seconds == 7
  end
end
