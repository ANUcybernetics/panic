defmodule PanicWeb.NetworkLive.FormComponent do
  use PanicWeb, :live_component

  alias Panic.Models

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
    attrs = run_params
    |> Map.put("model", socket.assigns.run.model)
    |> Map.put("network_id", socket.assigns.run.network_id)

    case Models.create_run(attrs) do
      {:ok, run} ->
        {:noreply,
         socket
         |> put_flash(:info, "Started run of #{run.model}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect changeset
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
