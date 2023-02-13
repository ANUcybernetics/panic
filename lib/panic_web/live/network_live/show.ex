defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.{Networks, Platforms}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:network, Networks.get_network!(id))}
  end

  @impl true
  def handle_event("append-model", %{"model" => model}, socket) do
    {:ok, network} = Networks.append_model(socket.assigns.network, model)
    {:noreply, assign(socket, :network, network)}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"

  ## TODO this is too clever by half... fix it
  defp grouped_model_options do
    Panic.Platforms.all_model_info()
    |> Enum.map(fn {model, info} -> Map.put(info, :model, model) end)
    |> Enum.group_by(
      fn %{input: input} -> input end,
      fn %{model: model, name: name} -> {name, model} end
    )
    |> Enum.map(fn {group, values} ->
      {"#{group |> Atom.to_string() |> String.capitalize()} input", values}
    end)
  end

  defp button_colour(input, last_output) when input == last_output, do: "bg-zinc-300"
  defp button_colour(:text, _), do: "bg-emerald-600"
  defp button_colour(:image, _), do: "bg-violet-700"

  def append_model_widget(assigns) do
    ~H"""
    <section class="p-4 mt-4 bg-zinc-100 rounded-lg">
      <h2 class="text-md font-semibold">Append Model</h2>
      <div class="mt-4 grid grid-cols-3 gap-2">
        <.button
          :for={{model, %{name: name, input: input}} <- Platforms.all_model_info()}
          class={
            button_colour(
              input,
              @current_models |> List.last() |> Platforms.model_info() |> Map.get(:output)
            )
          }
          phx-click={JS.push("append-model", value: %{model: model})}
        >
          <%= name %>
        </.button>
      </div>
    </section>
    """
  end
end
