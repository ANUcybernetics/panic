defmodule PanicWeb.InstallationLive.WatcherFormComponent do
  @moduledoc """
  Form component for adding a watcher to an installation, or editing one
  when `watcher_name` is given.
  """
  use PanicWeb, :live_component

  alias Panic.Watcher.Installation.Config

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>
          {if @watcher_name,
            do: "Update watcher configuration",
            else: "Configure how invocations should be displayed"}
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="watcher-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.inputs_for :let={watcher_form} field={@form[@watcher_field]}>
          <.input
            field={watcher_form[:type]}
            type="select"
            label="Type"
            options={[
              {"Grid - Display invocations in a grid layout", :grid},
              {"Single - Show one invocation at a time", :single},
              {"Vestaboard - Display for Vestaboard device", :vestaboard}
            ]}
          />

          <.input
            field={watcher_form[:name]}
            type="text"
            label="Name"
            placeholder="e.g. main-display"
            pattern="[a-zA-Z0-9-]+"
            title="Only letters, numbers, and hyphens allowed"
          />

          <div :if={watcher_form[:type].value == :grid} class="space-y-4">
            <.input field={watcher_form[:rows]} type="number" label="Rows" min="1" />
            <.input field={watcher_form[:columns]} type="number" label="Columns" min="1" />
          </div>

          <div :if={watcher_form[:type].value in [:single, :vestaboard]} class="space-y-4">
            <.input field={watcher_form[:stride]} type="number" label="Stride" min="1" />
            <.input field={watcher_form[:offset]} type="number" label="Offset" min="0" />
            <.input field={watcher_form[:show_invoking]} type="checkbox" label="Show Invoking State" />
            <p class="mt-1 text-sm text-gray-600">
              When enabled, invocations in the 'invoking' state will be displayed. When disabled, only completed, ready, and failed states are shown.
            </p>
          </div>

          <div :if={watcher_form[:type].value == :vestaboard} class="space-y-4">
            <.input
              field={watcher_form[:vestaboard_name]}
              type="select"
              label="Vestaboard Name"
              options={[
                {"Panic 1", :panic_1},
                {"Panic 2", :panic_2},
                {"Panic 3", :panic_3},
                {"Panic 4", :panic_4}
              ]}
            />
            <.input field={watcher_form[:initial_prompt]} type="checkbox" label="Show Initial Prompt" />
            <p class="mt-1 text-sm text-gray-600">
              When enabled, this vestaboard will display the initial prompt text when a new run starts
            </p>
          </div>
        </.inputs_for>

        <:actions>
          <.button phx-disable-with="Saving...">{if @watcher_name,
            do: "Update Watcher",
            else: "Add Watcher"}</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:watcher_name, fn -> nil end)

    # keep the user's edits when the parent re-renders
    socket = if socket.assigns[:form], do: socket, else: assign_form(socket)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           action_opts: [load: [:network]]
         ) do
      {:ok, installation} ->
        notify_parent({:saved, installation})

        {:noreply,
         socket
         |> put_flash(
           :info,
           if(socket.assigns.watcher_name,
             do: "Watcher updated successfully",
             else: "Watcher added successfully"
           )
         )
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(%{assigns: %{installation: installation, current_user: actor}} = socket) do
    form =
      case socket.assigns.watcher_name do
        nil ->
          Panic.Watcher.form_to_add_watcher(installation,
            actor: actor,
            params: %{"watcher" => %{"type" => "grid", "name" => ""}},
            forms: [watcher: [resource: Config, create_action: :create]]
          )

        watcher_name ->
          watcher = Enum.find(installation.watchers, &(&1.name == watcher_name))

          Panic.Watcher.form_to_update_watcher(installation, watcher_name,
            actor: actor,
            params: %{"updated_watcher" => Map.from_struct(watcher)},
            forms: [updated_watcher: [resource: Config, create_action: :create]]
          )
      end

    socket
    |> assign(
      :watcher_field,
      if(socket.assigns.watcher_name, do: :updated_watcher, else: :watcher)
    )
    |> assign(:form, to_form(form))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
