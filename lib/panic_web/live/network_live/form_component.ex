defmodule PanicWeb.NetworkLive.FormComponent do
  use PanicWeb, :live_component

  alias Panic.{Models, Networks}

  @impl true
  def update(%{run: run} = assigns, socket) do
    changeset = Models.change_run(run)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

end
