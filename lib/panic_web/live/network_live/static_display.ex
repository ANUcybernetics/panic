defmodule PanicWeb.NetworkLive.StaticDisplay do
  @moduledoc """
  Static (i.e. not updating in real-timm)display of network invocations.

  Currently only support single invocations, but will add a "static grid"
  view at some point.
  """
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  @impl true
  def render(assigns) do
    ~H"""
    <.invocation
      invocation={@invocation}
      model={@invocation.model |> List.last() |> Panic.Model.by_id!()}
      id={"invocation-#{@invocation.id}"}
    />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: {PanicWeb.Layouts, :display}}
  end

  @impl true
  def handle_params(%{"invocation_id" => invocation_id}, _session, socket) do
    # no auth required, because this is in a "login optional" route
    invocation = Ash.get!(Panic.Engine.Invocation, invocation_id, authorize?: false)
    # TODO use the live action and params (and add a :grid router path) to make this work for grids too
    display = {:single, 0, 1}

    {:noreply,
     assign(socket,
       page_title: "Panic invocation (network #{invocation.network_id})",
       invocation: invocation,
       display: display
     )}
  end
end
