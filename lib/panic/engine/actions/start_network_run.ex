defmodule Panic.Engine.Actions.StartNetworkRun do
  @moduledoc """
  Starts a run on the network with the given id (via `Invocation :start_run`)
  and returns the network, now showing its current run. This is the API's way
  in; the UI calls `Panic.Engine.start_run/3` with the network it already has.
  """
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, context) do
    opts = Ash.Context.to_opts(context)

    with {:ok, network} <- Panic.Engine.get_network(input.arguments.id, opts),
         {:ok, _genesis} <- Panic.Engine.start_run(network, input.arguments.input, opts) do
      Panic.Engine.get_network(network.id, opts)
    end
  end
end
