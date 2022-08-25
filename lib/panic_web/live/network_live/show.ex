defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models
  alias Panic.Models.Run
  alias Panic.Models.Platforms.{Replicate, OpenAI, HuggingFace}

  @num_slots 8

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
      [platform, model_name] = String.split(run.model, ":")

      output =
        case platform do
          "replicate" -> Replicate.create(model_name, run.input)
          "openai" -> OpenAI.create(model_name, run.input)
          "huggingface" -> HuggingFace.create(model_name, run.input)
        end

      case Models.update_run(run, %{output: output}) do
        {:ok, run} ->
          Networks.broadcast(run.network_id, {"run_succeeded", %{run | status: :succeeded}})
        {:error, changeset} ->
          IO.inspect {changeset, output}
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

    cycle_status =
      if Models.cycle_has_converged?(run.first_run_id) do
        :converged
      else
        socket.assigns.cycle_status
      end

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

  def run_widget(assigns) do
    ~H"""
    <div class="relative block w-full text-center text-gray-800 bg-gray-200 shadow-lg dark:bg-gray-800 hover:bg-gray-300 dark:text-gray-400 dark:group-hover:text-gray-100">
      <div class="h-48 grid place-items-center overflow-hidden">
        <%= if @run do %>
          <%= case @run.status do %>
            <% :created -> %>
              <Heroicons.Outline.minus_circle class="w-12 h-12 mx-auto" />
            <% :running -> %>
              <.spinner class="mx-auto" size="md" />
            <% :succeeded -> %>
              <%= case Models.model_io(@run.model) do %>
                <% {_, :text} -> %>
                  <div class="p-2 text-md text-left">
                    <%= for line <- String.split(@run.output, "\n\n") do %>
                      <%= unless line == "" do %>
                        <p><%= line %></p>
                      <% end %>
                    <% end %>
                  </div>
                <% {_, :image} -> %>
                  <img class="w-full object-cover" src={@run.output} />
                <% {_, :audio} -> %>
                  <audio autoplay controls={false} src={local_or_remote_url(@socket, @run.output)} />
                  <Heroicons.Outline.volume_up class="w-12 h-12 mx-auto" />
              <% end %>
            <% :failed -> %>
              <Heroicons.Outline.x_circle class="w-12 h-12 mx-auto" />
          <% end %>
          <div class="absolute left-2 -bottom-6">
            <%= @run.model |> String.split(~r/[:\/]/) |> List.last() %>
          </div>
        <% else %>
          <span class="text-gray-400 italic">blank</span>
        <% end %>
      </div>
    </div>
    """
  end

  def local_or_remote_url(socket, url) do
    if String.match?(url, ~r/https?:\/\//) do
      url
    else
      Routes.static_path(socket, "/model_outputs/" <> Path.basename(url))
    end
  end

  defp cycle_index(_cycle, %Run{parent_id: nil}), do: 0

  defp cycle_index(cycle, %Run{parent_id: parent_id}) do
    idx = Enum.find_index(cycle, fn run -> run && run.id == parent_id end)
    Integer.mod(idx + 1, Enum.count(cycle))
  end

  defp rotate([head | tail]), do: tail ++ [head]
end
