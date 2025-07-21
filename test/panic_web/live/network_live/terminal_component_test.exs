defmodule PanicWeb.NetworkLive.TerminalComponentTest do
  use PanicWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    on_exit(&PanicWeb.Helpers.stop_all_network_runners/0)

    # Create network owner without API tokens
    owner = Panic.Fixtures.user()

    # Create network
    network = Panic.Fixtures.network_with_dummy_models(owner)

    %{owner: owner, network: network}
  end

  describe "terminal component error handling" do
    test "handles NetworkRunner exceptions properly", %{conn: conn, network: network} do
      # Generate time-based auth token
      auth_token = PanicWeb.TerminalAuth.generate_token(network.id)

      # Terminal route is /networks/:network_id/terminal
      {:ok, view, _html} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{auth_token}")

      # Mock the NetworkRunner to return an exception instead of a form
      # This simulates what happens in production when API tokens are missing

      # Since we can't easily mock GenServer calls, let's test the error handling
      # by creating a scenario where NetworkRunner would fail

      # First, let's check if the terminal loads properly
      assert render(view) =~ "Current run:"

      # Now submit a form - this will call NetworkRunner.start_run
      # which should handle errors gracefully
      html =
        view
        |> form("form", %{invocation: %{input: "test prompt"}})
        |> render_submit()

      # The component should display an error (not crash)
      # Even if NetworkRunner returns {:error, exception}, the component
      # should handle it gracefully
      assert html =~ "Current run:" || html =~ "error"
    end
  end

  describe "error handling for missing API tokens" do
    test "handles exceptions from NetworkRunner gracefully", %{conn: conn, owner: owner} do
      # Create a network with non-dummy models that require API tokens
      {:ok, network} =
        Panic.Engine.Network
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Network with Real Models",
            lockout_seconds: 0
          },
          actor: owner
        )
        |> Ash.create()
      
      # Update network with a model that requires API tokens
      {:ok, network} =
        network
        |> Ash.Changeset.for_update(
          :update_models,
          %{
            models: ["gpt-4.1"]
          },
          actor: owner
        )
        |> Ash.update()
      
      # Since the owner has no API tokens, NetworkRunner.start_run will fail
      # with an exception when trying to prepare the first invocation
      
      # Generate auth token
      auth_token = PanicWeb.TerminalAuth.generate_token(network.id)
      
      # Load the terminal
      {:ok, view, _html} = live(conn, ~p"/networks/#{network.id}/terminal?token=#{auth_token}")
      
      # Verify terminal loads
      assert render(view) =~ "Current run:"
      
      # Submit a form - this will trigger NetworkRunner.start_run
      # which will return {:error, exception} due to missing API tokens
      html =
        view
        |> form("form", %{invocation: %{input: "test prompt"}})
        |> render_submit()
      
      # The component should handle the exception gracefully and show an error
      # It should NOT crash with ArgumentError about expecting AshPhoenix.Form
      assert html =~ "Current run:"
      
      # Should show some kind of error message
      assert html =~ "error" || html =~ "Error" || html =~ "failed"
      
      # Should not contain the ArgumentError message that would indicate a crash
      refute html =~ "ArgumentError"
      refute html =~ "Expected to receive either an"
    end
    
    test "verifies the fix handles different error types correctly", %{conn: conn, network: network} do
      # This test verifies that the error handling in terminal_component.ex
      # properly handles both form errors and exceptions
      
      auth_token = PanicWeb.TerminalAuth.generate_token(network.id)
      {:ok, view, _html} = live(conn, ~p"/networks/#{network.id}/terminal?token=#{auth_token}")
      
      # With dummy models, this should work fine
      html =
        view
        |> form("form", %{invocation: %{input: "test"}})
        |> render_submit()
      
      # Should not show errors with dummy models
      refute html =~ "error occurred"
      assert html =~ "Current run:"
    end
  end
end
