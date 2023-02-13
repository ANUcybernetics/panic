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

  defp button_colour(:text), do: "bg-emerald-600"
  defp button_colour(:image), do: "bg-violet-700"
end
