defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models
  alias Panic.Models.Run

  @num_slots 9

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :cycle_status, :waiting)}
  end

  @impl true
  def handle_params(%{"id" => network_id}, _, socket) do
    network = Networks.get_network!(network_id)
    models = network.models

    {:error, changeset} =
      Models.create_run(%{"model" => List.first(models), "network_id" => network.id})

    Networks.subscribe(network_id)

    {:noreply,
     socket
     |> assign(:page_title, "Show network")
     |> assign(:network, network)
     |> assign(:models, models)
     |> assign(:first_run, nil)
     |> assign(:first_run_changeset, changeset)
     |> assign(:cycle, List.duplicate(nil, @num_slots))
     |> assign(:cycle_length, 0)}
  end

  @impl true
  def handle_event("validate_first_run", %{"run" => run_params}, socket) do
    attrs =
      Map.merge(
        %{
          "model" => List.first(socket.assigns.models),
          "network_id" => socket.assigns.network.id
        },
        run_params
      )

    changeset =
      Models.change_run(%Run{}, attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :first_run_changeset, changeset)}
  end

  def handle_event("create_first_run", %{"run" => run_params}, socket) do
    models = socket.assigns.network.models

    attrs =
      Map.merge(
        %{
          "model" => List.first(models),
          "network_id" => socket.assigns.network.id
        },
        run_params
      )

    case Models.create_run(attrs) do
      {:ok, run} ->
        ## this is a first run, so populate the first_run_id accordingly
        {:ok, run_with_fr_id} = Models.update_run(run, %{first_run_id: run.id})
        Networks.broadcast(run.network_id, {"run_created", run_with_fr_id})

        ## reset changeset
        {:error, changeset} =
          Models.create_run(%{
            "model" => List.first(models),
            "network_id" => socket.assigns.network.id,
            "first_run_id" => run.id
          })

        {:noreply,
         socket
         |> assign(:models, rotate(models))
         |> assign(:first_run_changeset, changeset)
         |> assign(:cycle_status, :running)
         |> assign(:cycle_length, 0)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, first_run_changeset: changeset)}
    end
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     push_patch(socket, to: Routes.network_show_path(socket, :show, socket.assigns.network))}
  end

  @impl true
  def handle_event("start_cycle", _, socket) do
    {:noreply, assign(socket, :cycle_status, :running)}
  end

  @impl true
  def handle_event("stop_cycle", _, socket) do
    {:noreply, assign(socket, :cycle_status, :waiting)}
  end

  @impl true
  def handle_info({"run_created", run}, socket) do
    idx = cycle_index(socket.assigns.cycle, run)

    # now run the thing...
    Panic.BackgroundTask.run(fn ->
      output = Models.dispatch(run.model, run.input)

      case Models.update_run(run, %{output: output}) do
        {:ok, run} ->
          Networks.broadcast(run.network_id, {"run_succeeded", %{run | status: :succeeded}})

        {:error, changeset} ->
          IO.inspect({changeset, output})
      end
    end)

    cycle = List.replace_at(socket.assigns.cycle, idx, %{run | status: :running})
    first_run = if is_nil(run.parent_id), do: run, else: socket.assigns.first_run

    {:noreply,
     socket
     |> assign(:cycle, cycle)
     |> assign(:first_run, first_run)
     |> update(:cycle_length, fn length -> length + 1 end)}
  end

  @impl true
  def handle_info({"run_succeeded", run}, socket) do
    idx = cycle_index(socket.assigns.cycle, run)
    cycle = List.replace_at(socket.assigns.cycle, idx, run)

    ## note: there used to be a convergence check here, but SD doesn't need it
    cycle_status = socket.assigns.cycle_status

    if cycle_status == :running do
      attrs = %{
        model: List.first(socket.assigns.models),
        input: run.output,
        parent_id: run.id,
        first_run_id: run.first_run_id,
        network_id: run.network_id
      }

      {:ok, next_run} = Models.create_run(attrs)
      Networks.broadcast(run.network_id, {"run_created", next_run})
    end

    {:noreply,
     socket
     |> assign(:cycle, cycle)
     |> assign(:cycle_status, cycle_status)
     |> assign(
       :models,
       if(cycle_status == :running, do: rotate(socket.assigns.models), else: socket.assigns.models)
     )}
  end

  defp cycle_index(_cycle, %Run{parent_id: nil}), do: 0

  defp cycle_index(cycle, %Run{parent_id: parent_id}) do
    idx = Enum.find_index(cycle, fn run -> run && run.id == parent_id end)
    Integer.mod(idx + 1, Enum.count(cycle))
  end

  defp rotate([head | tail]), do: tail ++ [head]
end
