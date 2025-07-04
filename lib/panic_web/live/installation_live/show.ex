defmodule PanicWeb.InstallationLive.Show do
  @moduledoc """
  LiveView for showing installation details and managing watchers.
  """
  use PanicWeb, :live_view

  alias Panic.Engine.Installation
  alias PanicWeb.InvocationWatcher

  @impl true
  def render(assigns) do
    ~H"""
    <.back navigate={~p"/installations"}>Back to installations</.back>

    <.header>
      {@installation.name}
      <:subtitle>
        Network:
        <.link navigate={~p"/networks/#{@installation.network}"}>
          {@installation.network.name}
        </.link>
      </:subtitle>
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
      <div class="mt-4 space-y-4">
        <div :if={@installation.watchers == []} class="text-sm text-zinc-600 dark:text-zinc-400">
          No watchers configured. Add one to start displaying invocations.
        </div>
        <div
          :for={{watcher, index} <- Enum.with_index(@installation.watchers)}
          class="relative rounded-lg border border-zinc-200 dark:border-zinc-700 p-4"
        >
          <div class="flex justify-between items-start">
            <div class="flex-grow">
              <div class="flex items-center gap-3">
                <h3 class="text-base font-semibold text-zinc-900 dark:text-zinc-100">
                  {watcher.name}
                </h3>
                <span class="inline-flex items-center rounded-md bg-zinc-100 dark:bg-zinc-800 px-2 py-1 text-xs font-medium text-zinc-700 dark:text-zinc-300">
                  {watcher.type}
                </span>
                <span class="inline-flex items-center rounded-md bg-green-100 dark:bg-green-900 px-2 py-1 text-xs font-medium text-green-800 dark:text-green-200">
                  <svg class="mr-1 h-3 w-3" fill="currentColor" viewBox="0 0 8 8">
                    <circle cx="4" cy="4" r="3" />
                  </svg>
                  {count_viewers_for_watcher(@installation, watcher)} viewers
                </span>
              </div>
              <div class="mt-2 text-sm text-zinc-600 dark:text-zinc-400">
                {watcher_summary(watcher)}
              </div>
              <div class="mt-2">
                <.link
                  navigate={~p"/i/#{@installation.id}/#{watcher.name}"}
                  class="text-sm text-indigo-600 hover:text-indigo-500 dark:text-indigo-400 dark:hover:text-indigo-300"
                >
                  View display (/i/{@installation.id}/{watcher.name}) →
                </.link>
              </div>
            </div>
            <div class="flex gap-2">
              <.link
                patch={~p"/installations/#{@installation}/show/edit_watcher/#{index}"}
                class="text-sm text-zinc-600 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
              >
                Edit
              </.link>
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
        networks={@networks}
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

    <.modal
      :if={@live_action == :edit_watcher}
      id="watcher-edit-modal"
      show
      on_cancel={JS.patch(~p"/installations/#{@installation}")}
    >
      <.live_component
        module={PanicWeb.InstallationLive.WatcherEditFormComponent}
        id={@watcher_index}
        title="Edit Watcher"
        installation={@installation}
        index={@watcher_index}
        current_user={@current_user}
        patch={~p"/installations/#{@installation}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :networks, list_networks(socket.assigns.current_user))}
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

  defp apply_action(socket, :edit_watcher, %{"index" => index}) do
    index = String.to_integer(index)
    assign(socket, :watcher_index, index)
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

  @impl true
  def handle_info({PanicWeb.InstallationLive.WatcherEditFormComponent, {:saved, installation}}, socket) do
    {:noreply, assign(socket, :installation, installation)}
  end

  defp page_title(:show), do: "Show Installation"
  defp page_title(:edit), do: "Edit Installation"
  defp page_title(:add_watcher), do: "Add Watcher"
  defp page_title(:edit_watcher), do: "Edit Watcher"

  defp list_networks(user) do
    Ash.read!(Panic.Engine.Network, actor: user)
  end

  defp count_viewers_for_watcher(installation, _watcher) do
    viewers = InvocationWatcher.list_viewers(installation.network_id)
    
    # Count viewers that are viewing this installation
    # We can't match specific watchers without tracking more metadata in presence
    Enum.count(viewers, fn viewer ->
      viewer[:installation_id] == to_string(installation.id)
    end)
  end

  defp watcher_summary(watcher) do
    case watcher.type do
      :grid ->
        "#{watcher.rows} × #{watcher.columns} grid"
      
      :single ->
        show_invoking = if watcher.show_invoking, do: " (shows invoking)", else: ""
        "Shows every #{ordinalize(watcher.stride)} invocation, offset #{watcher.offset}#{show_invoking}"
      
      :vestaboard ->
        show_invoking = if watcher.show_invoking, do: " (shows invoking)", else: ""
        initial = if watcher.initial_prompt, do: ", shows initial prompt", else: ""
        "#{String.capitalize(String.replace(to_string(watcher.vestaboard_name), "_", " "))} - every #{ordinalize(watcher.stride)}, offset #{watcher.offset}#{show_invoking}#{initial}"
    end
  end

  defp ordinalize(1), do: "1st"
  defp ordinalize(2), do: "2nd"
  defp ordinalize(3), do: "3rd"
  defp ordinalize(n) when n in 11..13, do: "#{n}th"
  defp ordinalize(n) when rem(n, 10) == 1, do: "#{n}st"
  defp ordinalize(n) when rem(n, 10) == 2, do: "#{n}nd"
  defp ordinalize(n) when rem(n, 10) == 3, do: "#{n}rd"
  defp ordinalize(n), do: "#{n}th"
end
