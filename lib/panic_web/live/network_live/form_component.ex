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

  @impl true
  def handle_event("validate", %{"run" => run_params}, socket) do
    changeset =
      socket.assigns.run
      |> Models.change_run(run_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("create_run", %{"run" => run_params}, socket) do
    case Models.create_run(socket.assigns.run, run_params) do
      {:ok, run} ->
        Networks.broadcast(run.network_id, {"run_created", %{run | status: :created}})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
