defmodule PanicWeb.InstallationLive.Show do
  @moduledoc """
  LiveView for showing installation details and managing watchers.
  """
  use PanicWeb, :live_view

  alias Panic.Engine.Installation

  @impl true
  def render(assigns) do
    ~H"""
    <.back navigate={~p"/installations"}>Back to installations</.back>

    <.header>
      {@installation.name}
      <:subtitle>Network: {@installation.network.name}</:subtitle>
      <:actions>
        <.link patch={~p"/installations/#{@installation}/show/edit"} phx-click={JS.push_focus()}>
          <.button>Edit installation</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-10">
      <h2 class="text-lg font-semibold leading-8 text-zinc-800 dark:text-zinc-100">
        Watchers
      </h2>
      <div class="mt-4 space-y-6">
        <div :if={@installation.watchers == []} class="text-sm text-zinc-600 dark:text-zinc-400">
          No watchers configured. Add one to start displaying invocations.
        </div>
        <div
          :for={{watcher, index} <- Enum.with_index(@installation.watchers)}
          class="relative rounded-lg border border-zinc-200 dark:border-zinc-700 p-4"
        >
          <div class="pr-10">
            <h3 class="text-base font-semibold leading-7 text-zinc-900 dark:text-zinc-100">
              {watcher_title(watcher, index)}
            </h3>
            <.list>
              <:item title="Type">{watcher.type}</:item>
              <:item :if={watcher.type == :grid} title="Dimensions">
                {watcher.rows} × {watcher.columns}
              </:item>
              <:item :if={watcher.type in [:single, :vestaboard]} title="Stride">
                {watcher.stride}
              </:item>
              <:item :if={watcher.type in [:single, :vestaboard]} title="Offset">
                {watcher.offset}
              </:item>
              <:item :if={watcher.type == :vestaboard} title="Name">
                {watcher.name}
              </:item>
              <:item :if={watcher.type == :vestaboard} title="Initial Prompt">
                {if watcher.initial_prompt, do: "Yes", else: "No"}
              </:item>
            </.list>
            <div class="mt-4">
              <.link
                navigate={~p"/i/#{@installation.id}/#{index}"}
                class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700 dark:text-zinc-100 dark:hover:text-zinc-300"
              >
                View watcher →
              </.link>
            </div>
          </div>
          <div class="absolute right-2 top-2">
            <.link
              phx-click={JS.push("delete_watcher", value: %{index: index})}
              data-confirm="Are you sure you want to delete this watcher?"
              class="text-sm text-red-600 hover:text-red-500"
            >
              Delete
            </.link>
          </div>
        </div>
      </div>
      <div class="mt-6">
        <.link patch={~p"/installations/#{@installation}/show/add_watcher"}>
          <.button>Add watcher</.button>
        </.link>
      </div>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="installation-modal"
      show
      on_cancel={JS.patch(~p"/installations/#{@installation}")}
    >
      <.live_component
        module={PanicWeb.InstallationLive.FormComponent}
        id={@installation.id}
        title={@page_title}
        action={@live_action}
        installation={@installation}
        current_user={@current_user}
        networks={[@installation.network]}
        patch={~p"/installations/#{@installation}"}
      />
    </.modal>

    <.modal
      :if={@live_action == :add_watcher}
      id="watcher-modal"
      show
      on_cancel={JS.patch(~p"/installations/#{@installation}")}
    >
      <.live_component
        module={PanicWeb.InstallationLive.WatcherFormComponent}
        id={:new}
        title="Add Watcher"
        installation={@installation}
        current_user={@current_user}
        patch={~p"/installations/#{@installation}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    installation = Ash.get!(Installation, id, actor: socket.assigns.current_user, load: [:network])

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:installation, installation)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  defp apply_action(socket, :edit, _params) do
    socket
  end

  defp apply_action(socket, :add_watcher, _params) do
    socket
  end

  @impl true
  def handle_event("delete_watcher", %{"index" => index}, socket) do
    index = if is_binary(index), do: String.to_integer(index), else: index

    {:ok, installation} =
      socket.assigns.installation
      |> Ash.Changeset.for_update(:remove_watcher, %{index: index}, actor: socket.assigns.current_user)
      |> Ash.update()

    {:noreply, assign(socket, :installation, installation)}
  end

  @impl true
  def handle_info({PanicWeb.InstallationLive.FormComponent, {:saved, installation}}, socket) do
    {:noreply, assign(socket, :installation, installation)}
  end

  @impl true
  def handle_info({PanicWeb.InstallationLive.WatcherFormComponent, {:saved, installation}}, socket) do
    {:noreply, assign(socket, :installation, installation)}
  end

  defp page_title(:show), do: "Show Installation"
  defp page_title(:edit), do: "Edit Installation"
  defp page_title(:add_watcher), do: "Add Watcher"

  defp watcher_title(%{type: :grid} = watcher, index) do
    "Watcher #{index}: Grid (#{watcher.rows}×#{watcher.columns})"
  end

  defp watcher_title(%{type: :single} = watcher, index) do
    "Watcher #{index}: Single (stride: #{watcher.stride}, offset: #{watcher.offset})"
  end

  defp watcher_title(%{type: :vestaboard} = watcher, index) do
    prompt_indicator = if watcher.initial_prompt, do: ", initial prompt", else: ""

    "Watcher #{index}: Vestaboard #{watcher.name} (stride: #{watcher.stride}, offset: #{watcher.offset}#{prompt_indicator})"
  end
end
