defmodule PanicWeb.NetworkLive.Edit do
  use PanicWeb, :live_view

  alias Panic.{Networks, Models}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    network = Networks.get_network!(id)

    {:noreply,
     socket
     |> assign(:page_title, "Edit network")
     |> assign(:network, network)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     push_patch(socket, to: Routes.network_edit_path(socket, :edit, socket.assigns.network))}
  end

  @impl true
  def handle_event("append_model", %{"value" => model}, socket) do
    {:ok, network} = Networks.append_model(socket.assigns.network, model)

    {:noreply, assign(socket, :network, network)}
  end

  @impl true
  def handle_event("remove_model", %{"pos" => pos}, socket) do
    index = String.to_integer(pos)
    {:ok, network} = Networks.remove_model(socket.assigns.network, index)

    {:noreply, assign(socket, :network, network)}
  end

  @impl true
  def handle_event("move_model_up", %{"pos" => pos}, socket) do
    initial_index = String.to_integer(pos)
    final_index = initial_index - 1
    {:ok, network} = Networks.reorder_models(socket.assigns.network, initial_index, final_index)

    {:noreply, assign(socket, :network, network)}
  end

  @impl true
  def handle_event("move_model_down", %{"pos" => pos}, socket) do
    initial_index = String.to_integer(pos)
    final_index = initial_index + 1
    {:ok, network} = Networks.reorder_models(socket.assigns.network, initial_index, final_index)

    {:noreply, assign(socket, :network, network)}
  end

  defp models_with_validation([]), do: []

  defp models_with_validation(models) do
    n = Enum.count(models)

    for {model, i} <- Enum.with_index(models) do
      valid? =
        io_valid?(
          Models.model_io(Enum.at(models, Integer.mod(i - 1, n))),
          Models.model_io(model),
          Models.model_io(Enum.at(models, Integer.mod(i + 1, n))),
          i
        )

      {model, i, valid?}
    end
  end

  defp io_valid?(_, {input, _}, _, 0), do: input == :text

  defp io_valid?({_, prev_output}, {input, output}, {next_input, _}, _index) do
    prev_output == input && output == next_input
  end

  defp model_display_string(model) do
    model |> String.split(~r/[:]/) |> List.last()
  end

  def model_io_color(io, prefix \\ "") do
    color = Map.get(%{text: "violet-500", image: "orange-500", audio: "emerald-500"}, io, "")
    prefix <> color
  end

  defp model_input_color(model) do
    {input, _output} = Models.model_io(model)
    model_io_color(input, "bg-")
  end

  defp model_output_color(model) do
    {_input, output} = Models.model_io(model)
    model_io_color(output, "bg-")
  end
end
