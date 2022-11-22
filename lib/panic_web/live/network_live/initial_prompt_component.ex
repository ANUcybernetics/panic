defmodule PanicWeb.NetworkLive.InitialPromptComponent do
  use PanicWeb, :live_component

  alias Panic.Networks
  alias Panic.Models

  @impl true
  def update(%{network: network} = assigns, socket) do
    {:error, changeset} = Models.create_first_run(network)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"run" => params}, socket) do
    changeset =
      socket.assigns.changeset.data
      |> Models.change_run(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def handle_event("start-cycle", %{"run" => params}, socket) do
    network = socket.assigns.network

    case Models.create_first_run(network, params) do
      {:ok, run} ->
        # dispatch it (async) to the relevant API
        Models.dispatch_run(run)
        Networks.broadcast(run.network_id, {:run_created, %{run | status: :running}})

        {:error, next_changeset} = Models.create_first_run(network)

        {:noreply, assign(socket, changeset: next_changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("start-cycle", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(%{terminal: false} = assigns) do
    ~H"""
    <div>
      <div class="flex mb-4 gap-2 justify-end">
        <.button
          class="bg-red-600 hover:bg-red-400"
          link_type="button"
          phx_click="stop_cycle"
          label="Stop"
        />
        <.button
          link_type="live_patch"
          label="Edit"
          to={Routes.network_edit_path(@socket, :edit, @network.id)}
        />
        <.button link_type="live_patch" label="Back" to={Routes.network_index_path(@socket, :index)} />
        <.button type="submit" phx_disable_with="Panicking..." label="Panic" />
      </div>

      <.form
        :let={f}
        for={@changeset}
        id={@id}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="start-cycle"
      >
        <.form_field type="text_input" form={f} field={:input} label="input" />
      </.form>
    </div>
    """
  end

  @impl true
  def render(%{terminal: true} = assigns) do
    ~H"""
    <div>
      <.form
        :let={f}
        for={@changeset}
        id={@id}
        phx-target={@myself}
        phx-change="validate"
        phx-submit={JS.push("start-cycle")}
        autocomplete="off"
      >
        <.text_input
          id={"panic-main-textinput"}
          class="disabled:bg-rose-300"
          disabled={@timer > 0}
          form={f}
          field={:input}
          placeholder={placeholder_text(@timer)}
          autocomplete="false"
        />
      </.form>
    </div>
    """
  end

  defp placeholder_text(timer) when timer > 0, do: "ready for new input in #{timer}s..."
  defp placeholder_text(timer), do: "type your input"
end
