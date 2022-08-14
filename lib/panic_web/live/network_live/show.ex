defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models
  alias Panic.Models.Run
  alias Panic.Models.Platforms.Replicate

  @num_slots 8

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :cycle_status, :running)}
  end

  @impl true
  def handle_params(%{"id" => network_id}, _, socket) do
    network = Networks.get_network!(network_id)
    models = network.models

    # create, but don't persist to the db until it starts (it's not valid, anyway)
    first_run = %Run{model: List.first(models), network_id: String.to_integer(network_id), status: :created}

    Networks.subscribe(network_id)

    {:noreply,
     socket
     |> assign(:page_title, "Show network")
     |> assign(:network, network)
     |> assign(:models, rotate(models))
     |> assign(:first_run, first_run)
     |> assign_new(:cycle, fn -> List.duplicate(nil, @num_slots) end)
    }
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     push_patch(socket, to: Routes.network_show_path(socket, :show, socket.assigns.network))}
  end

  @impl true
  def handle_event("start_cycle", _, socket) do
    IO.puts("starting...")
    {:noreply, assign(socket, :cycle_status, :running)}
  end

  @impl true
  def handle_event("stop_cycle", _, socket) do
    IO.puts("stopping...")
    {:noreply, assign(socket, :cycle_status, :stopped)}
  end

  @impl true
  def handle_info({"run_created", run}, socket) do
    is_first_run? = is_nil(run.parent_id)

    idx = if is_first_run?, do: 0, else: find_parent_index(socket.assigns.cycle, run.parent_id)
    cycle = List.replace_at(socket.assigns.cycle, idx, %{run | status: :running})

    # now run the thing...
    Panic.BackgroundTask.run(fn ->
      [platform, model_name] = String.split(run.model, ":")
      output =
        case platform do
          "replicate" -> Replicate.create(model_name, run.input)
        end

      {:ok, run} = Models.update_run(run, %{output: output})
      Networks.broadcast(run.network_id, {"run_succeeded", run})
    end)

    ## there's probably a more idiomatic way to do this...
    first_run = if is_first_run?, do: socket.assigns.first_run, else: run

    {:noreply, assign(socket, cycle: cycle, first_run: first_run)}
  end

  @impl true
  def handle_info({"run_succeeded", run}, socket) do
    idx = find_run_index(socket.assigns.cycle, run.id)
    cycle = List.replace_at(socket.assigns.cycle, idx + 1, %{run | status: :succeeded})

    IO.inspect {run, idx}

    if socket.assigns.cycle_status == :running do
      attrs = %{
        model: List.first(socket.assigns.models),
        parent_id: run.id,
        input: run.output,
        network_id: run.network_id,
        status: :created
      }
      {:ok, next_run} = Models.create_run(attrs)
      Networks.broadcast(run.network_id, {"run_created", next_run})
    end

    {:noreply, assign(socket, cycle: cycle, models: rotate(socket.assigns.models))}
  end

  def run_widget(assigns) do
    ~H"""
    <div class="relative block w-full p-12 text-center text-gray-800 bg-gray-200 rounded-lg shadow-lg dark:bg-gray-800 hover:bg-gray-300 dark:text-gray-400 dark:group-hover:text-gray-100">
      <span class="block my-4 font-medium ">
        <%= case @run && @run.status do %>
          <% :created -> %>
            <Heroicons.Outline.minus_circle class="w-12 h-12 mx-auto" />
          <% :running -> %>
            <.spinner class="mx-auto" size="md" />
          <% :succeeded -> %>
            <Heroicons.Outline.check_circle class="w-12 h-12 mx-auto" />
            <%= @run.output %>
          <% :failed -> %>
            <Heroicons.Outline.x_circle class="w-12 h-12 mx-auto" />
          <% nil -> %>
        <% end %>
      </span>
    </div>
    """
  end

  def find_run_index(cycle, run_id) do
    idx = Enum.find_index(cycle, fn run -> run && run.id == run_id  end)
    Integer.mod(idx, Enum.count(cycle))
  end

  def find_parent_index(cycle, parent_id) do
    idx = Enum.find_index(cycle, fn run -> run && run.id == parent_id  end)
    Integer.mod(idx, Enum.count(cycle))
  end

  defp rotate([head | tail]), do: tail ++ [head]
end
